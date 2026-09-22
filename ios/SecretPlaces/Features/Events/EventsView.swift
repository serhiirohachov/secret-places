import SwiftUI
import MapKit

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [EventItem] = []
    @Published var state: LoadState<Bool> = .idle

    func load(_ env: AppEnvironment, cityId: String? = nil, limit: Int = 50) async {
        if events.isEmpty { state = .loading }
        do {
            events = try await env.events.upcoming(cityId: cityId, limit: limit)
            state = .loaded(true)
        } catch let e as AppError {
            state = e == .offline ? .offline : .failed(e)
        } catch { state = .failed(.unknown(error.localizedDescription)) }
    }
}

/// Афіша — upcoming events / posters happening in the city.
struct EventsView: View {
    var cityId: String? = nil
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = EventsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                switch vm.state {
                case .idle, .loading: LoadingView()
                case .offline: ErrorStateView(error: .offline) { Task { await vm.load(env, cityId: cityId) } }
                case .failed(let e): ErrorStateView(error: e) { Task { await vm.load(env, cityId: cityId) } }
                default:
                    if vm.events.isEmpty {
                        EmptyStateView(icon: "ticket", title: "No events yet", message: "New posters land here as the city wakes up.")
                    } else {
                        ForEach(vm.events) { event in
                            NavigationLink(value: event) {
                                EventCard(event: event).padding(.horizontal, 14)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .background(Theme.bg)
        .navigationTitle("Афіша")
        .withAppDestinations()
        .task { if case .idle = vm.state { await vm.load(env, cityId: cityId) } }
    }
}

struct EventCard: View {
    let event: EventItem
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: event.posterUrl, height: 170)
                if event.featured {
                    Text("Featured").font(.caption2.weight(.bold))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(Theme.accent).padding(10)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(event.dateLabel).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(event.title).font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                if let venue = event.venueTeaser {
                    Label(venue, systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                HStack(spacing: 8) {
                    PriceTag(label: event.priceLabel, isFree: event.isFree)
                    if !event.lineup.isEmpty {
                        Text(event.lineup.prefix(2).joined(separator: " · "))
                            .font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                }
            }
            .padding(12)
        }
        .cardBackground()
    }
}

// MARK: - Event detail

struct EventDetailView: View {
    let event: EventItem
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImage(url: event.posterUrl, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text(event.dateLabel).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text(event.title).font(.title2.bold()).foregroundStyle(Theme.text)
                    PriceTag(label: event.priceLabel, isFree: event.isFree)

                    if let desc = event.description, !desc.isEmpty {
                        Text(desc).font(.body).foregroundStyle(Theme.textMuted)
                    }

                    if !event.lineup.isEmpty {
                        SectionHeader(title: "Lineup").padding(.top, 6)
                        FlexibleWrap(event.lineup) { name in
                            Text(name).font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Theme.surface).foregroundStyle(Theme.text)
                                .clipShape(Capsule())
                        }
                    }

                    if let venue = event.venueTeaser {
                        SectionHeader(title: "Where").padding(.top, 6)
                        Label(venue, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(Theme.textMuted)
                        Text("Exact address is revealed on the venue's page once unlocked.")
                            .font(.caption).foregroundStyle(Theme.textMuted)
                        eventMap
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 10)
        }
        .background(Theme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { if event.ticketUrl != nil { ticketBar } }
        .withAppDestinations()
    }

    @ViewBuilder private var eventMap: some View {
        if let la = event.venueApproxLat, let ln = event.venueApproxLng {
            let coord = CLLocationCoordinate2D(latitude: la, longitude: ln)
            Map(initialPosition: .region(MKCoordinateRegion(center: coord, latitudinalMeters: 1200, longitudinalMeters: 1200))) {
                // Approximate area only — never the exact pin for paid venues.
                MapCircle(center: coord, radius: 350)
                    .foregroundStyle(Theme.accent.opacity(0.18))
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .allowsHitTesting(false)
        }
    }

    private var ticketBar: some View {
        Button {
            if let s = event.ticketUrl, let u = URL(string: s) { openURL(u) }
        } label: {
            Label("Get tickets", systemImage: "ticket.fill")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(Theme.accent)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

extension EventItem {
    var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM · HH:mm"
        return f.string(from: startsAt)
    }
}
