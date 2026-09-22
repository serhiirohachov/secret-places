import Foundation

/// Provides the current access token (nil ⇒ act as anonymous with the anon key).
protocol SessionProviding: AnyObject, Sendable {
    var accessToken: String? { get }
}

/// Lightweight Supabase REST/RPC client over URLSession.
/// Full production interface — not a mock. Uses the publishable anon key plus
/// the user's JWT (when signed in) so RLS is enforced server-side.
final class SupabaseClient: @unchecked Sendable {
    private let session: URLSession
    private weak var sessionProvider: SessionProviding?
    let decoder: JSONDecoder
    let encoder: JSONEncoder
    /// Invoked on a 401 to refresh auth (or fall back to anon). Returns true to retry once.
    var onUnauthorized: (@Sendable () async -> Bool)?

    init(session: URLSession = .shared, sessionProvider: SessionProviding? = nil) {
        self.session = session
        self.sessionProvider = sessionProvider
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func setSessionProvider(_ provider: SessionProviding) { self.sessionProvider = provider }

    private func authHeaders() -> [String: String] {
        let token = sessionProvider?.accessToken ?? Config.supabaseAnonKey
        return [
            "apikey": Config.supabaseAnonKey,
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json",
        ]
    }

    // MARK: REST select

    /// GET a PostgREST resource (table or view) with a raw query string.
    func select<T: Decodable>(_ resource: String, query: [URLQueryItem], as: T.Type) async throws -> T {
        var comps = URLComponents(url: Config.restURL.appendingPathComponent(resource), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        authHeaders().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await run(req, as: T.self)
    }

    // MARK: RPC

    func rpc<T: Decodable>(_ name: String, params: [String: AnyEncodable] = [:], as: T.Type) async throws -> T {
        var req = URLRequest(url: Config.restURL.appendingPathComponent("rpc/\(name)"))
        req.httpMethod = "POST"
        authHeaders().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = try encoder.encode(params)
        return try await run(req, as: T.self)
    }

    // MARK: Mutations (authenticated)

    @discardableResult
    func insert<Body: Encodable, T: Decodable>(_ resource: String, body: Body, as: T.Type, upsert: Bool = false) async throws -> T {
        var req = URLRequest(url: Config.restURL.appendingPathComponent(resource))
        req.httpMethod = "POST"
        authHeaders().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.setValue(upsert ? "resolution=merge-duplicates,return=representation" : "return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try encoder.encode(body)
        return try await run(req, as: T.self)
    }

    func delete(_ resource: String, query: [URLQueryItem]) async throws {
        var comps = URLComponents(url: Config.restURL.appendingPathComponent(resource), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        authHeaders().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        _ = try await runData(req)
    }

    // MARK: Edge functions

    func callFunction<Body: Encodable, T: Decodable>(_ name: String, body: Body, as: T.Type) async throws -> T {
        var req = URLRequest(url: Config.functionsURL.appendingPathComponent(name))
        req.httpMethod = "POST"
        authHeaders().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = try encoder.encode(body)
        return try await run(req, as: T.self)
    }

    // MARK: Core

    private func run<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let data = try await runData(req)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw AppError.decoding(String(describing: error)) }
    }

    private func runData(_ req: URLRequest, allowRetry: Bool = true) async throws -> Data {
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw AppError.network("no response") }
            if http.statusCode == 401, allowRetry, let handler = onUnauthorized, await handler() {
                var retry = req
                let token = sessionProvider?.accessToken ?? Config.supabaseAnonKey
                retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                return try await runData(retry, allowRetry: false)
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw AppError.server(status: http.statusCode, message: msg)
            }
            return data
        } catch let e as AppError {
            throw e
        } catch let urlErr as URLError where urlErr.code == .notConnectedToInternet || urlErr.code == .networkConnectionLost {
            throw AppError.offline
        } catch {
            throw AppError.network(error.localizedDescription)
        }
    }
}

/// Type-erased Encodable for heterogeneous RPC params.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
