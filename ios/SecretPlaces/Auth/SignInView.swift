import SwiftUI
import AuthenticationServices
import CryptoKit

struct SignInView: View {
    var reason: String = "Sign in to sync your unlocked secrets and saves across devices."
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentNonce: String?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles").font(.system(size: 52)).foregroundStyle(Theme.accent)
            Text("Secret Places").font(.largeTitle.bold()).foregroundStyle(Theme.text)
            Text(reason).font(.subheadline).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonce()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)

            Button("Continue as guest") { dismiss() }.tint(Theme.textMuted).padding(.bottom)
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth0):
            guard let credential = auth0.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                error = "Could not read Apple credentials."; return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            Task {
                do {
                    try await auth.signInWithApple(idToken: idToken, nonce: currentNonce, fullName: name.isEmpty ? nil : name)
                    await env.refreshUserState()
                    await env.entitlements.refresh()
                    dismiss()
                } catch { self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription }
            }
        case .failure(let err):
            if (err as? ASAuthorizationError)?.code != .canceled { error = err.localizedDescription }
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < UInt8(chars.count) { result.append(chars[Int(random)]); remaining -= 1 }
        }
        return result
    }
    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
