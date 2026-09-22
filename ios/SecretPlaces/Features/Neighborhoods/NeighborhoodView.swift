import SwiftUI

struct NeighborhoodView: View {
    let neighborhood: Neighborhood
    @EnvironmentObject private var env: AppEnvironment
    @State private var state: LoadState<[PlaceTeaser]> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let d = neighborhood.description {
                    Text(d).font(.body).foregroundStyle(Theme.textMuted).padding(.horizontal, 14).padding(.top, 8)
                }
                switch state {
                case .idle, .loading: LoadingView()
                case .empty: EmptyStateView(icon: "mappin.slash", title: "No secrets yet", message: "This neighborhood is being curated.")
                case .offline: ErrorStateView(error: .offline) { Task { await load() } }
                case .failed(let e): ErrorStateView(error: e) { Task { await load() } }
                case .loaded(let places):
                    Text("\(places.count) Secrets · \(places.filter { $0.isFreeExperience }.count) Free")
                        .font(.subheadline).foregroundStyle(Theme.accent).padding(.horizontal, 14)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(places) { p in
                            NavigationLink(value: p) { PlaceCard(place: p, isSaved: env.savedIds.contains(p.id)) }
                                .buttonStyle(.plain)
                        }
                    }.padding(14)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle(neighborhood.title)
        .withAppDestinations()
        .task { await load(); env.analytics.track(.neighborhoodView(slug: neighborhood.slug)) }
    }

    private func load() async {
        state = .loading
        do {
            let places = try await env.places.list(PlaceQuery(neighborhoodId: neighborhood.id, limit: 100))
            state = places.isEmpty ? .empty : .loaded(places)
        } catch let e as AppError { state = e == .offline ? .offline : .failed(e) }
        catch { state = .failed(.unknown(error.localizedDescription)) }
    }
}
