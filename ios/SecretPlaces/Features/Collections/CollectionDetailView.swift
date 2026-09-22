import SwiftUI

struct CollectionDetailView: View {
    let collection: PlaceCollection
    @EnvironmentObject private var env: AppEnvironment
    @State private var places: [PlaceTeaser] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RemoteImage(url: collection.coverUrl, height: 200)
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.title).font(.largeTitle.bold()).foregroundStyle(.white)
                        Text("\(places.count) places").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    }.padding()
                }
                if let d = collection.description { Text(d).font(.body).foregroundStyle(Theme.textMuted).padding(.horizontal, 14) }
                if loading { LoadingView() }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(places) { p in NavigationLink(value: p) { PlaceCard(place: p, isSaved: env.savedIds.contains(p.id)) }.buttonStyle(.plain) }
                }.padding(14)
            }.padding(.bottom, 30)
        }
        .background(Theme.bg).ignoresSafeArea(edges: .top)
        .navigationTitle(collection.title).navigationBarTitleDisplayMode(.inline)
        .withAppDestinations()
        .task {
            env.analytics.track(.collectionOpened(slug: collection.slug))
            places = (try? await env.collections.places(collectionId: collection.id)) ?? []
            loading = false
        }
    }
}
