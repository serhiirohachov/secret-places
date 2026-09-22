import Foundation
import StoreKit

struct VerifyPurchaseResponse: Decodable {
    let unlocked: Bool
    let kind: String?
    let placeId: String?
    let place: PlaceDetails?
    let routeId: String?
    let route: RouteDetails?
}

/// StoreKit 2 purchase layer. Verifies transactions server-side via the
/// verify-purchase Edge Function, which is the trust boundary that grants
/// the entitlement. Handles purchase, restore, pending (Ask to Buy),
/// cancellation, failure and revocation/refund via the transaction listener.
@MainActor
final class PurchaseService: ObservableObject {
    @Published private(set) var purchasingProductId: String?
    @Published private(set) var products: [String: Product] = [:]

    private let client: SupabaseClient
    private let auth: AuthStore
    private let entitlements: SupabaseEntitlementService
    private let analytics: AnalyticsService
    private var updatesTask: Task<Void, Never>?

    init(client: SupabaseClient, auth: AuthStore, entitlements: SupabaseEntitlementService, analytics: AnalyticsService) {
        self.client = client
        self.auth = auth
        self.entitlements = entitlements
        self.analytics = analytics
        listenForTransactions()
    }

    deinit { updatesTask?.cancel() }

    // MARK: Products

    func product(for productId: String) async -> Product? {
        if let p = products[productId] { return p }
        let loaded = (try? await Product.products(for: [productId])) ?? []
        for p in loaded { products[p.id] = p }
        return products[productId]
    }

    func priceLabel(for productId: String, fallback: String = Config.defaultPriceLabel) async -> String {
        await product(for: productId)?.displayPrice ?? fallback
    }

    // MARK: Purchase

    /// Purchase and unlock a place. Requires a signed-in user (entitlement is stored per-account).
    func purchase(placeId: String, productId: String) async throws -> PlaceDetails? {
        guard auth.isSignedIn else { throw AppError.notAuthenticated }
        guard let product = await product(for: productId) else { throw AppError.purchaseFailed("product_unavailable") }

        analytics.track(.placeUnlockStarted(placeId: placeId))
        purchasingProductId = productId
        defer { purchasingProductId = nil }

        let result: Product.PurchaseResult
        do { result = try await product.purchase() }
        catch { analytics.track(.placeUnlockFailed(placeId: placeId, reason: "storekit")); throw AppError.purchaseFailed(error.localizedDescription) }

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            let unlocked = try await sync(jws: verification.jwsRepresentation, placeId: placeId)
            await transaction.finish()
            entitlements.markUnlocked(placeId)
            analytics.track(.placeUnlockSuccess(placeId: placeId))
            return unlocked?.place
        case .userCancelled:
            analytics.track(.placeUnlockFailed(placeId: placeId, reason: "cancelled"))
            throw AppError.purchaseCancelled
        case .pending:
            analytics.track(.placeUnlockFailed(placeId: placeId, reason: "pending"))
            throw AppError.purchasePending
        @unknown default:
            throw AppError.purchaseFailed("unknown")
        }
    }

    /// Purchase a route (e.g. a bar crawl). Grants a route entitlement that
    /// unlocks every place the route contains.
    func purchaseRoute(routeSlug: String, productId: String) async throws -> RouteDetails? {
        guard auth.isSignedIn else { throw AppError.notAuthenticated }
        guard let product = await product(for: productId) else { throw AppError.purchaseFailed("product_unavailable") }
        purchasingProductId = productId
        defer { purchasingProductId = nil }
        let result: Product.PurchaseResult
        do { result = try await product.purchase() }
        catch { throw AppError.purchaseFailed(error.localizedDescription) }
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            struct Body: Encodable { let transactionJWS: String; let routeSlug: String }
            let resp = try await client.callFunction("verify-purchase",
                body: Body(transactionJWS: verification.jwsRepresentation, routeSlug: routeSlug),
                as: VerifyPurchaseResponse.self)
            await transaction.finish()
            await entitlements.refresh()
            return resp.route
        case .userCancelled: throw AppError.purchaseCancelled
        case .pending: throw AppError.purchasePending
        @unknown default: throw AppError.purchaseFailed("unknown")
        }
    }

    // MARK: Restore

    /// Restore purchases: re-sync every current entitlement to the server.
    func restore() async throws {
        guard auth.isSignedIn else { throw AppError.notAuthenticated }
        try? await AppStore.sync()
        for await result in Transaction.currentEntitlements {
            if case .verified = result {
                _ = try? await sync(jws: result.jwsRepresentation, placeId: nil)
            }
        }
        await entitlements.refresh()
    }

    // MARK: Server sync (trust boundary)

    @discardableResult
    private func sync(jws: String, placeId: String?) async throws -> VerifyPurchaseResponse? {
        struct Body: Encodable { let transactionJWS: String; let placeId: String? }
        return try await client.callFunction("verify-purchase", body: Body(transactionJWS: jws, placeId: placeId), as: VerifyPurchaseResponse.self)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw AppError.purchaseFailed("unverified: \(error.localizedDescription)")
        }
    }

    // MARK: Transaction listener (Ask to Buy approvals, refunds, revocations)

    private func listenForTransactions() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = update {
                    if transaction.revocationDate != nil {
                        // Refunded / revoked → refresh entitlements from server.
                        await self.entitlements.refresh()
                    } else if self.auth.isSignedIn {
                        _ = try? await self.sync(jws: update.jwsRepresentation, placeId: nil)
                        await self.entitlements.refresh()
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
