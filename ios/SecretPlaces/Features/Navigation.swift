import SwiftUI

/// Registers shared navigation destinations for a NavigationStack.
struct AppDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: PlaceTeaser.self) { PlaceDetailView(placeId: $0.id, teaser: $0) }
            .navigationDestination(for: City.self) { CityView(city: $0) }
            .navigationDestination(for: Neighborhood.self) { NeighborhoodView(neighborhood: $0) }
            .navigationDestination(for: Category.self) { cat in
                PlacesListView(title: cat.title, query: PlaceQuery(categoryId: cat.id))
            }
            .navigationDestination(for: PlaceCollection.self) { CollectionDetailView(collection: $0) }
            .navigationDestination(for: EventItem.self) { EventDetailView(event: $0) }
            .navigationDestination(for: RouteSummary.self) { RouteDetailView(slug: $0.slug, summary: $0) }
    }
}

extension View {
    func withAppDestinations() -> some View { modifier(AppDestinations()) }
}
