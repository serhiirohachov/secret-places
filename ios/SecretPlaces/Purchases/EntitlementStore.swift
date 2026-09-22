import Foundation

/// Server-synced entitlements (source of truth = user_entitlements via RLS).
/// Caches only the SET OF UNLOCKED PLACE IDS locally for offline checks —
/// never the sensitive place data.
final class SupabaseEntitlementService: EntitlementService, @unchecked Sendable {
    private let client: SupabaseClient
    private let session: TokenHolder
    private let lock = NSLock()
    private var cache: Set<String> = []
    private let cacheKey = "sp_unlocked_ids"

    init(client: SupabaseClient, session: TokenHolder) {
        self.client = client
        self.session = session
        if let ids = UserDefaults.standard.array(forKey: cacheKey) as? [String] {
            cache = Set(ids)
        }
    }

    func unlockedPlaceIds() async throws -> Set<String> {
        guard session.isSignedIn else { return currentCache() }
        struct Row: Decodable { let placeId: String? }
        let rows = try await client.select(
            "user_entitlements",
            query: [URLQueryItem(name: "select", value: "place_id"),
                    URLQueryItem(name: "revoked_at", value: "is.null")],
            as: [Row].self)
        let ids = Set(rows.compactMap { $0.placeId })
        store(ids)
        return ids
    }

    func isUnlocked(placeId: String) async -> Bool {
        currentCache().contains(placeId)
    }

    func refresh() async {
        _ = try? await unlockedPlaceIds()
    }

    private func currentCache() -> Set<String> { lock.lock(); defer { lock.unlock() }; return cache }
    private func store(_ ids: Set<String>) {
        lock.lock(); cache = ids; lock.unlock()
        UserDefaults.standard.set(Array(ids), forKey: cacheKey)
    }
    func markUnlocked(_ placeId: String) {
        lock.lock(); cache.insert(placeId); let snapshot = cache; lock.unlock()
        UserDefaults.standard.set(Array(snapshot), forKey: cacheKey)
    }
    func clear() { store([]) }
}
