import Foundation

/// App configuration, read from Info.plist (injected via xcconfig/project settings).
enum Config {
    static let supabaseURL: URL = {
        let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        return URL(string: s) ?? URL(string: "https://qovfroivqskzelpuxfwp.supabase.co")!
    }()

    static let supabaseAnonKey: String =
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvdmZyb2l2cXNremVscHV4ZndwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwNjIwODUsImV4cCI6MjEwNTYzODA4NX0.MhnCgGyf39DSH4F841mjzCxhFARTLjVLbxr-vRXQD6Q"

    /// Default unlock price shown before StoreKit products load.
    static let defaultPriceLabel = "$0.99"

    static var restURL: URL { supabaseURL.appendingPathComponent("rest/v1") }
    static var authURL: URL { supabaseURL.appendingPathComponent("auth/v1") }
    static var functionsURL: URL { supabaseURL.appendingPathComponent("functions/v1") }
}
