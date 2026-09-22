import SwiftUI

/// Reusable list screen for a PlaceQuery (category, city, neighborhood, filters).
struct PlacesListView: View {
    let title: String
    let query: PlaceQuery
    @EnvironmentObject private var env: AppEnvironment
    @State private var state: LoadState<[PlaceTeaser]> = .idle

    var body: some View {
        ScrollView {
            switch state {
            case .idle, .loading: LoadingView()
            case .empty: EmptyStateView(icon: "mappin.slash", title: "No secrets here yet", message: "Check back soon — new places are added regularly.")
            case .offline: ErrorStateView(error: .offline) { Task { await load() } }
            case .failed(let e): ErrorStateView(error: e) { Task { await load() } }
            case .loaded(let places):
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(places) { p in
                        NavigationLink(value: p) { PlaceCard(place: p, isSaved: env.savedIds.contains(p.id)) }
                            .buttonStyle(.plain)
                    }
                }.padding(14)
            }
        }
        .background(Theme.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .withAppDestinations()
        .task { if state.value == nil { await load() } }
    }

    private func load() async {
        state = .loading
        do {
            let places = try await env.places.list(query)
            state = places.isEmpty ? .empty : .loaded(places)
        } catch let e as AppError {
            state = e == .offline ? .offline : .failed(e)
        } catch { state = .failed(.unknown(error.localizedDescription)) }
    }
}
