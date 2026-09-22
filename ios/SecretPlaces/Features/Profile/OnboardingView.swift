import SwiftUI

/// Minimal, optional onboarding: pick interests + optionally enable location.
struct OnboardingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private let interests = ["nature","cocktails","coffee","architecture","beaches","road trips","date spots","nightlife","quiet places","photography","viewpoints","culture"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("What do you love?").font(.title2.bold()).foregroundStyle(Theme.text)
                    Text("We use this to rank what you see first — you'll still see everything.").font(.subheadline).foregroundStyle(Theme.textMuted)
                    FlexibleWrap(interests) { interest in
                        Button {
                            if selected.contains(interest) { selected.remove(interest) } else { selected.insert(interest) }
                        } label: {
                            Text(interest.capitalized)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(selected.contains(interest) ? Theme.accent : Theme.surface)
                                .foregroundStyle(selected.contains(interest) ? .black : Theme.text)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                    Button { if location.authorization == .notDetermined { location.requestPermission() } } label: {
                        Label("Enable location (optional)", systemImage: "location").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).tint(Theme.accent)
                }.padding()
            }
            .background(Theme.bg)
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { Task { await env.saveInterests(Array(selected)); dismiss() } }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Skip") { dismiss() } }
            }
        }
    }
}
