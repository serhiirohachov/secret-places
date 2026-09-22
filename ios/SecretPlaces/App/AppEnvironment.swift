import Foundation
import SwiftUI

/// Dependency container. Constructed once and injected via the SwiftUI environment.
/// Uses protocols for every service so tests/previews can inject mocks.
@MainActor
final class AppEnvironment: ObservableObject {
    let client: SupabaseClient
    let auth: AuthStore
    let analytics: AnalyticsService

    let places: PlaceRepository
    let geo: GeoRepository
    let categoriesRepo: CategoryRepository
    let collections: CollectionsRepository
    let search: SearchService
    let saved: SavedPlacesRepository
    let ratings: RatingsRepository
    let reports: ReportsRepository

    let entitlements: SupabaseEntitlementService
    let purchases: PurchaseService
    let location: LocationService

    /// Cached categories (backend-configured, not hardcoded).
    @Published var categories: [Category] = []
    @Published var savedIds: Set<String> = []
    @Published var placeStatuses: [String: PlaceUserStatus] = [:]

    init(preview: Bool = false) {
        let auth = AuthStore()
        let client = SupabaseClient(sessionProvider: auth.tokens)
        let analytics = ConsoleAnalytics()

        self.auth = auth
        self.client = client
        self.analytics = analytics

        self.places = SupabasePlaceRepository(client: client)
        self.geo = SupabaseGeoRepository(client: client)
        self.categoriesRepo = SupabaseCategoryRepository(client: client)
        self.collections = SupabaseCollectionsRepository(client: client)
        self.search = SupabaseSearchService(client: client)
        self.saved = SupabaseSavedPlacesRepository(client: client, session: auth.tokens)
        self.ratings = SupabaseRatingsRepository(client: client, session: auth.tokens)
        self.reports = SupabaseReportsRepository(client: client, session: auth.tokens)

        let entitlements = SupabaseEntitlementService(client: client, session: auth.tokens)
        self.entitlements = entitlements
        self.purchases = PurchaseService(client: client, auth: auth, entitlements: entitlements, analytics: analytics)
        self.location = LocationService()
    }

    func bootstrap() async {
        // Skip network work when the app is only hosting a unit-test bundle.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        analytics.track(.appOpen)
        if let cats = try? await categoriesRepo.categories() { categories = cats }
        await entitlements.refresh()
        await refreshUserState()
    }

    func refreshUserState() async {
        guard auth.isSignedIn else { savedIds = []; placeStatuses = [:]; return }
        if let ids = try? await saved.savedIds() { savedIds = ids }
        if let st = try? await saved.statuses() { placeStatuses = st }
    }

    func isUnlocked(_ placeId: String) async -> Bool { await entitlements.isUnlocked(placeId: placeId) }

    func category(for id: String?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    // Saved toggles with optimistic UI.
    func toggleSaved(_ placeId: String) async {
        if savedIds.contains(placeId) {
            savedIds.remove(placeId)
            try? await saved.unsave(placeId: placeId)
        } else {
            savedIds.insert(placeId)
            analytics.track(.placeSaved(placeId: placeId))
            try? await saved.save(placeId: placeId)
        }
    }

    /// Persist onboarding interests (used to rank Discover — never to hide content).
    func saveInterests(_ interests: [String]) async {
        guard let uid = auth.currentUserId else { return }
        struct Body: Encodable { let id: String; let interests: [String]; let onboarded: Bool }
        struct Row: Decodable { let id: String? }
        _ = try? await client.insert("profiles", body: [Body(id: uid, interests: interests, onboarded: true)], as: [Row].self, upsert: true)
    }

    /// Full account + data deletion via the delete-account Edge Function (service role).
    func deleteAccount() async throws {
        struct Empty: Encodable {}
        struct Resp: Decodable { let deleted: Bool? }
        _ = try await client.callFunction("delete-account", body: Empty(), as: Resp.self)
        auth.signOut()
        entitlements.clear()
        await DiskCache.shared.clearAll()
        savedIds = []; placeStatuses = [:]
    }

    func setStatus(_ placeId: String, _ status: PlaceUserStatus?) async {
        if let status { placeStatuses[placeId] = status } else { placeStatuses[placeId] = nil }
        if status == .visited { analytics.track(.placeVisited(placeId: placeId)) }
        try? await saved.setStatus(placeId: placeId, status: status)
    }
}
