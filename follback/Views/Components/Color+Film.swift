import SwiftUI

extension Color {
    // MARK: - FilmVault Cinematic Palette
    // Rich, warm analog aesthetic with depth and sophistication

    /// Primary background — deep charcoal with warm undertone
    static let filmBackground = Color(hex: "#0A0908")

    /// Card / elevated surface — warm dark
    static let filmSurface = Color(hex: "#171412")

    /// Secondary surface (inputs, inner cards)
    static let filmSurfaceSecondary = Color(hex: "#0E0C0A")

    /// Elevated surface for modals/popovers
    static let filmSurfaceElevated = Color(hex: "#1E1A16")

    /// Primary accent — rich amber gold
    static let filmAccent = Color(hex: "#E8A832")

    /// Secondary accent — deep warm gold
    static let filmGold = Color(hex: "#C47F17")

    /// Tertiary accent — rose copper
    static let filmCopper = Color(hex: "#B87333")

    /// Primary text — warm pearl white
    static let filmText = Color(hex: "#F5F0E8")

    /// Secondary text — warm gray
    static let filmSecondary = Color(hex: "#B5A898")

    /// Tertiary / muted text
    static let filmTertiary = Color(hex: "#7A6E62")

    /// Borders and dividers
    static let filmBorder = Color(hex: "#2C2620")

    /// Subtle border for hover/focus states
    static let filmBorderActive = Color(hex: "#3D352C")

    /// Empty / placeholder fill
    static let filmSprocket = Color(hex: "#100E0B")

    /// Status / success — emerald
    static let filmSuccess = Color(hex: "#34D399")

    /// Status / warning — amber
    static let filmWarning = Color(hex: "#FBBF24")

    /// Status / error — soft red
    static let filmError = Color(hex: "#F87171")

    /// Status / info — sky blue
    static let filmInfo = Color(hex: "#60A5FA")

    /// Gradient start for aurora effects
    static let filmGradientStart = Color(hex: "#E8A832")

    /// Gradient mid
    static let filmGradientMid = Color(hex: "#D97706")

    /// Gradient end
    static let filmGradientEnd = Color(hex: "#B87333")

    /// Glass tint for glassmorphism
    static let filmGlass = Color(hex: "#1A1612")

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

// MARK: - Gradient Presets
extension LinearGradient {
    static let filmAccentGradient = LinearGradient(
        colors: [Color.filmGradientStart, Color.filmGradientMid, Color.filmGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let filmWarmGradient = LinearGradient(
        colors: [Color.filmAccent, Color.filmGold],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let filmSubtleGradient = LinearGradient(
        colors: [Color.filmAccent.opacity(0.15), Color.filmGold.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let filmGlassGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Reusable View Modifiers
struct FilmCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                    )
            )
    }
}

struct FilmGlassStyle: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.filmGlass.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                    )
            )
    }
}

struct FilmAccentGlow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color.filmAccent.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func filmCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(FilmCardStyle(cornerRadius: cornerRadius))
    }

    func filmGlass(cornerRadius: CGFloat = 20) -> some View {
        modifier(FilmGlassStyle(cornerRadius: cornerRadius))
    }

    func filmGlow() -> some View {
        modifier(FilmAccentGlow())
    }
}
