import Foundation
import Combine

/// Thread-safe holder for the current session (token + user id), read by the
/// network client and repositories from any context, written by AuthStore on
/// the main actor.
final class TokenHolder: SessionProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _token: String?
    private var _userId: String?
    var accessToken: String? { lock.lock(); defer { lock.unlock() }; return _token }
    var userId: String? { lock.lock(); defer { lock.unlock() }; return _userId }
    var isSignedIn: Bool { accessToken != nil }
    func set(token: String?, userId: String?) { lock.lock(); _token = token; _userId = userId; lock.unlock() }
}

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var email: String?
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
    struct AuthUser: Decodable { let id: String; let email: String? }
}

protocol AuthServicing: AnyObject {
    var currentUserId: String? { get }
    var isSignedIn: Bool { get }
    func signInWithApple(idToken: String, nonce: String?, fullName: String?) async throws
    func signOut()
}

/// Sign in with Apple → Supabase session. Guest browsing is the default (no session).
@MainActor
final class AuthStore: ObservableObject, AuthServicing {
    @Published private(set) var session: AuthSession?
    let tokens = TokenHolder()

    private let defaultsKey = "sp_auth_session"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let s = try? JSONDecoder().decode(AuthSession.self, from: data) {
            session = s
            tokens.set(token: s.accessToken, userId: s.userId)
        }
    }

    var currentUserId: String? { session?.userId }
    var isSignedIn: Bool { session != nil }

    func signInWithApple(idToken: String, nonce: String?, fullName: String?) async throws {
        var comps = URLComponents(url: Config.authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["provider": "apple", "id_token": idToken]
        if let nonce { body["nonce"] = nonce }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.server(status: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                                  message: String(data: data, encoding: .utf8) ?? "auth failed")
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tr = try decoder.decode(TokenResponse.self, from: data)
        let s = AuthSession(accessToken: tr.accessToken, refreshToken: tr.refreshToken, userId: tr.user.id, email: tr.user.email)
        apply(s)
    }

    #if DEBUG
    /// DEBUG-only email/password sign-in for local testing of the full purchase
    /// flow without the Apple provider configured. Not compiled into release.
    func devSignIn(email: String = "dev@secretplaces.app", password: String = "devpass123") async throws {
        var comps = URLComponents(url: Config.authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.server(status: (resp as? HTTPURLResponse)?.statusCode ?? -1, message: String(data: data, encoding: .utf8) ?? "dev auth failed")
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tr = try decoder.decode(TokenResponse.self, from: data)
        apply(AuthSession(accessToken: tr.accessToken, refreshToken: tr.refreshToken, userId: tr.user.id, email: tr.user.email))
    }
    #endif

    func signOut() {
        session = nil
        tokens.set(token: nil, userId: nil)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func apply(_ s: AuthSession) {
        session = s
        tokens.set(token: s.accessToken, userId: s.userId)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: defaultsKey) }
    }
}
