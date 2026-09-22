import SwiftUI

/// Placeholder-safe remote image (neutral placeholder — never a fake photo of a real place).
struct RemoteImage: View {
    let url: String?
    var height: CGFloat = 180
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.surface2, Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let s = url, let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Image(systemName: "mappin.and.ellipse").font(.title).foregroundStyle(Theme.textMuted)
                    }
                }
            } else {
                Image(systemName: "mappin.and.ellipse").font(.title).foregroundStyle(Theme.textMuted)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

struct PriceTag: View {
    let label: String
    let isFree: Bool
    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isFree ? Theme.free.opacity(0.2) : Theme.locked.opacity(0.2))
            .foregroundStyle(isFree ? Theme.free : Theme.locked)
            .clipShape(Capsule())
    }
}

struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2.weight(.bold))
            .padding(6)
            .background(.ultraThinMaterial, in: Circle())
            .foregroundStyle(Theme.locked)
    }
}

/// Teaser card used across Discover, lists, search.
struct PlaceCard: View {
    let place: PlaceTeaser
    var isSaved: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RemoteImage(url: place.heroImageUrl, height: 150)
                HStack {
                    if !place.isFreeExperience { LockBadge() }
                    if isSaved { Image(systemName: "bookmark.fill").font(.caption2).padding(6).background(.ultraThinMaterial, in: Circle()).foregroundStyle(Theme.accent) }
                }.padding(8)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(place.teaserTitle).font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                Text(place.teaserDescription).font(.subheadline).foregroundStyle(Theme.textMuted).lineLimit(2)
                HStack(spacing: 8) {
                    PriceTag(label: place.priceLabel, isFree: place.isFreeExperience)
                    if place.ratingsCount > 0 {
                        Label(String(format: "%.1f", place.rating), systemImage: "star.fill")
                            .font(.caption).foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    if place.editorsChoice {
                        Text("Editor's pick").font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding(12)
        }
        .cardBackground()
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold()).foregroundStyle(Theme.text)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.textMuted) }
        }
    }
}

struct LoadingView: View {
    var body: some View { ProgressView().tint(Theme.accent).frame(maxWidth: .infinity, minHeight: 120) }
}

struct EmptyStateView: View {
    let icon: String, title: String, message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Theme.textMuted)
            Text(title).font(.headline).foregroundStyle(Theme.text)
            Text(message).font(.subheadline).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct ErrorStateView: View {
    let error: AppError
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: error == .offline ? "wifi.slash" : "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(Theme.locked)
            Text(error.errorDescription ?? "Something went wrong").font(.subheadline).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
            if let retry { Button("Try again", action: retry).buttonStyle(.borderedProminent).tint(Theme.accent) }
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

/// A wrapping flow layout for chips/tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct FlexibleWrap<Content: View>: View {
    let items: [String]
    let content: (String) -> Content
    init(_ items: [String], @ViewBuilder content: @escaping (String) -> Content) {
        self.items = items; self.content = content
    }
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}
