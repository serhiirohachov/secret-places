import Foundation

/// Typed errors surfaced across the app.
enum AppError: Error, Equatable, LocalizedError {
    case notAuthenticated
    case network(String)
    case decoding(String)
    case server(status: Int, message: String)
    case notFound
    case purchaseFailed(String)
    case purchaseCancelled
    case purchasePending
    case entitlementMissing
    case offline
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You need to sign in to do that."
        case .network(let m): return "Network problem: \(m)"
        case .decoding(let m): return "Could not read the data: \(m)"
        case .server(let s, let m): return "Server error (\(s)): \(m)"
        case .notFound: return "Not found."
        case .purchaseFailed(let m): return "Purchase failed: \(m)"
        case .purchaseCancelled: return "Purchase cancelled."
        case .purchasePending: return "Purchase is pending approval."
        case .entitlementMissing: return "This place isn't unlocked yet."
        case .offline: return "You're offline."
        case .unknown(let m): return m
        }
    }
}
