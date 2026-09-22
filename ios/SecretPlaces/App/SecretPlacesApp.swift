import SwiftUI

@main
struct SecretPlacesApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(env.auth)
                .environmentObject(env.purchases)
                .environmentObject(env.location)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { await env.bootstrap() }
        }
    }
}
