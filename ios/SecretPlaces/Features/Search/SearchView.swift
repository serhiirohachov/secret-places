import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var results = SearchResults()
    @State private var searching = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if searching { LoadingView() }
                else if !text.isEmpty && results.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "No matches", message: "Try a city, neighborhood, category or vibe — “sunset”, “date”, “rooftop”.")
                } else {
                    if !results.cities.isEmpty {
                        SectionHeader(title: "Cities")
                        ForEach(results.cities) { c in NavigationLink(value: c) { row(c.title, "building.2") }.buttonStyle(.plain) }
                    }
                    if !results.neighborhoods.isEmpty {
                        SectionHeader(title: "Neighborhoods")
                        ForEach(results.neighborhoods) { n in NavigationLink(value: n) { row(n.title, "mappin.circle") }.buttonStyle(.plain) }
                    }
                    if !results.places.isEmpty {
                        SectionHeader(title: "Secret places")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(results.places) { p in NavigationLink(value: p) { PlaceCard(place: p, isSaved: env.savedIds.contains(p.id)) }.buttonStyle(.plain) }
                        }
                    }
                }
            }.padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $text, prompt: "Kyiv, Golden Gate, cocktail, sunset…")
        .withAppDestinations()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        .onChange(of: text) { _, newValue in
            task?.cancel()
            task = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await run(newValue)
            }
        }
    }

    private func row(_ title: String, _ icon: String) -> some View {
        HStack { Image(systemName: icon).foregroundStyle(Theme.accent); Text(title).foregroundStyle(Theme.text); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textMuted) }
            .padding(14).cardBackground()
    }

    private func run(_ q: String) async {
        guard q.trimmingCharacters(in: .whitespaces).count >= 2 else { results = SearchResults(); return }
        searching = true
        results = (try? await env.search.search(q)) ?? SearchResults()
        searching = false
        env.analytics.track(.searchPerformed(queryLength: q.count))
    }
}
