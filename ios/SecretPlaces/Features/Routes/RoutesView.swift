import SwiftUI

@MainActor
final class RoutesViewModel: ObservableObject {
    @Published var routes: [RouteSummary] = []
    @Published var state: LoadState<Bool> = .idle

    func load(_ env: AppEnvironment, cityId: String? = nil) async {
        if routes.isEmpty { state = .loading }
        do {
            routes = try await env.routes.list(cityId: cityId)
            state = .loaded(true)
        } catch let e as AppError {
            state = e == .offline ? .offline : .failed(e)
        } catch { state = .failed(.unknown(error.localizedDescription)) }
    }
}

/// Bar crawls & curated routes.
struct RoutesView: View {
    var cityId: String? = nil
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = RoutesViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                switch vm.state {
                case .idle, .loading: LoadingView()
                case .offline: ErrorStateView(error: .offline) { Task { await vm.load(env, cityId: cityId) } }
                case .failed(let e): ErrorStateView(error: e) { Task { await vm.load(env, cityId: cityId) } }
                default:
                    if vm.routes.isEmpty {
                        EmptyStateView(icon: "figure.walk.motion", title: "No crawls yet", message: "Curated routes across the city's best rooms land here.")
                    } else {
                        ForEach(vm.routes) { route in
                            NavigationLink(value: route) {
                                RouteCard(route: route).padding(.horizontal, 14)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .background(Theme.bg)
        .navigationTitle("Bar crawls")
        .withAppDestinations()
        .task { if case .idle = vm.state { await vm.load(env, cityId: cityId) } }
    }
}

struct RouteCard: View {
    let route: RouteSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RemoteImage(url: route.coverUrl, height: 160)
                if !route.isFree { LockBadge().padding(10) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(route.title).font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                if let s = route.summary { Text(s).font(.subheadline).foregroundStyle(Theme.textMuted).lineLimit(2) }
                HStack(spacing: 10) {
                    PriceTag(label: route.priceLabel, isFree: route.isFree)
                    Label("\(route.stopCount) stops", systemImage: "mappin.circle")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                    if let d = route.durationMin {
                        Label("\(d) min", systemImage: "clock").font(.caption).foregroundStyle(Theme.textMuted)
                    }
                }
            }
            .padding(12)
        }
        .cardBackground()
    }
}
