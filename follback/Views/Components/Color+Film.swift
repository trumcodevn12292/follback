import SwiftUI

extension Color {
    // MARK: - FilmVault Darkroom Palette (static dark-only)
    // App maintains a consistent dark "analog darkroom" aesthetic

    /// Primary background — warm espresso
    static let filmBackground = Color(hex: "#0F0D0A")

    /// Card / elevated surface
    static let filmSurface = Color(hex: "#1C1814")

    /// Secondary surface (inputs, inner cards)
    static let filmSurfaceSecondary = Color(hex: "#14110E")

    /// Primary accent — warm amber
    static let filmAccent = Color(hex: "#D97706")

    /// Secondary accent — gold
    static let filmGold = Color(hex: "#B45309")

    /// Primary text — warm white
    static let filmText = Color(hex: "#F2EDE6")

    /// Secondary text
    static let filmSecondary = Color(hex: "#A89B8C")

    /// Tertiary / muted text
    static let filmTertiary = Color(hex: "#6B5E52")

    /// Borders and dividers
    static let filmBorder = Color(hex: "#2A2520")

    /// Empty / placeholder fill
    static let filmSprocket = Color(hex: "#12100D")

    /// Status / success
    static let filmSuccess = Color(hex: "#10B981")

    /// Status / warning
    static let filmWarning = Color(hex: "#F59E0B")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
