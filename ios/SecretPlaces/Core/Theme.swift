import SwiftUI

/// Design tokens — dark, editorial, "secret" aesthetic.
enum Theme {
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let surface2 = Color(red: 0.16, green: 0.16, blue: 0.20)
    static let text = Color.white
    static let textMuted = Color(white: 0.65)
    static let accent = Color(red: 0.85, green: 0.72, blue: 0.42)   // warm gold
    static let free = Color(red: 0.35, green: 0.78, blue: 0.55)
    static let locked = Color(red: 0.80, green: 0.55, blue: 0.35)

    static let corner: CGFloat = 18
}

extension View {
    func cardBackground() -> some View {
        background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}
