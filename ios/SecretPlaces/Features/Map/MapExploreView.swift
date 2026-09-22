import SwiftUI
import MapKit

@MainActor
final class MapViewModel: ObservableObject {
    @Published var places: [PlaceTeaser] = []
    @Published var selected: PlaceTeaser?

    func load(_ env: AppEnvironment) async {
        places = (try? await env.places.list(PlaceQuery(limit: 200))) ?? []
    }
}

/// Map exploration. Locked places are shown at their APPROX position only —
/// never the exact pin. Exact reveal happens on the detail screen after unlock.
struct MapExploreView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var location: LocationService
    @StateObject private var vm = MapViewModel()
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: .init(latitude: 50.45, longitude: 30.52), span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15)))

    var body: some View {
        Map(position: $camera, selection: $vm.selected) {
            ForEach(vm.places) { p in
                if let c = p.approxCoordinate {
                    Marker(p.teaserTitle, systemImage: p.isFreeExperience ? "leaf.fill" : "lock.fill", coordinate: c)
                        .tint(p.isFreeExperience ? Theme.free : Theme.locked)
                        .tag(p)
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay(alignment: .topLeading) {
            Text("Locked places show an approximate area, not the exact pin.")
                .font(.caption).padding(8).background(.ultraThinMaterial, in: Capsule()).padding(10)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { Task { await centerOnUser() } } label: {
                Image(systemName: "location.fill").padding(12).background(.ultraThinMaterial, in: Circle())
            }.padding(16)
        }
        .sheet(item: $vm.selected) { p in
            NavigationStack {
                PlaceDetailView(placeId: p.id, teaser: p)
                    .navigationBarTitleDisplayMode(.inline)
            }.presentationDetents([.large])
        }
        .navigationTitle("Map")
        .task { await vm.load(env); env.analytics.track(.mapOpened) }
    }

    private func centerOnUser() async {
        if location.authorization == .notDetermined { location.requestPermission() }
        if let c = await location.requestLocation() {
            camera = .region(MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.08, longitudeDelta: 0.08)))
        }
    }
}
