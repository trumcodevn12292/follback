import SwiftUI

extension Color {
    // MARK: - FilmVault Cinematic Palette
    // Rich, warm analog aesthetic with depth and sophistication.
    // All tokens are adaptive — they automatically switch between dark and
    // light variants based on the current color scheme.
    // Light palette uses warm paper-tone inspired by darkroom prints.

    /// Create a color that resolves differently in dark and light mode.
    static func adaptive(dark: String, light: String) -> Color {
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// Primary background — deep charcoal (dark) / warm paper (light)
    static let filmBackground = adaptive(dark: "#0A0908", light: "#FFFFFF")

    /// Card / elevated surface
    static let filmSurface = adaptive(dark: "#171412", light: "#FFFFFF")

    /// Secondary surface (inputs, inner cards)
    static let filmSurfaceSecondary = adaptive(dark: "#0E0C0A", light: "#FFFFFF")

    /// Elevated surface for modals/popovers
    static let filmSurfaceElevated = adaptive(dark: "#1E1A16", light: "#FFFFFF")

    /// Default accent hex (rich amber gold).
    static let defaultAccentHex = "#E8A832"

    /// Primary accent — user-customizable in Settings → Appearance.
    /// Computed so changing the stored accent updates the whole app.
    static var filmAccent: Color {
        Color(hex: UserDefaults.standard.string(forKey: "accentColorHex") ?? defaultAccentHex)
    }

    /// Secondary accent — deep warm gold
    static let filmGold = adaptive(dark: "#C47F17", light: "#92600F")

    /// Tertiary accent — rose copper
    static let filmCopper = adaptive(dark: "#B87333", light: "#8B5A26")

    /// Primary text — warm pearl white (dark) / warm near-black (light)
    static let filmText = adaptive(dark: "#F5F0E8", light: "#1A1410")

    /// Secondary text — warm gray
    static let filmSecondary = adaptive(dark: "#B5A898", light: "#5C4F42")

    /// Tertiary / muted text
    static let filmTertiary = adaptive(dark: "#7A6E62", light: "#8A7B6E")

    /// Borders and dividers
    static let filmBorder = adaptive(dark: "#2C2620", light: "#D5CCBE")

    /// Subtle border for hover/focus states
    static let filmBorderActive = adaptive(dark: "#3D352C", light: "#C0B5A8")

    /// Empty / placeholder fill
    static let filmSprocket = adaptive(dark: "#100E0B", light: "#E8E2D8")

    /// Status / success — emerald
    static let filmSuccess = adaptive(dark: "#34D399", light: "#059669")

    /// Status / warning — amber
    static let filmWarning = adaptive(dark: "#FBBF24", light: "#D97706")

    /// Status / error — soft red
    static let filmError = adaptive(dark: "#F87171", light: "#DC2626")

    /// Status / info — sky blue
    static let filmInfo = adaptive(dark: "#60A5FA", light: "#2563EB")

    /// Gradient start for aurora effects
    static let filmGradientStart = adaptive(dark: "#E8A832", light: "#D4942E")

    /// Gradient mid
    static let filmGradientMid = adaptive(dark: "#D97706", light: "#B86405")

    /// Gradient end
    static let filmGradientEnd = adaptive(dark: "#B87333", light: "#9E6328")

    /// Glass tint for glassmorphism
    static let filmGlass = adaptive(dark: "#1A1612", light: "#FFFFFF")

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
    static var filmAccentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.filmAccent, Color.filmGradientMid, Color.filmGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var filmWarmGradient: LinearGradient {
        LinearGradient(
            colors: [Color.filmAccent, Color.filmGold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var filmSubtleGradient: LinearGradient {
        LinearGradient(
            colors: [Color.filmAccent.opacity(0.15), Color.filmGold.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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

    func filmFadeIn(appeared: Bool, delay: Double = 0) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay), value: appeared)
    }

    func filmScaleIn(appeared: Bool, delay: Double = 0) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
            .animation(.spring(response: 0.45, dampingFraction: 0.78).delay(delay), value: appeared)
    }
}

// MARK: - Custom Animation Presets
extension Animation {
    static let filmSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let filmSnappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let filmSmooth = Animation.easeInOut(duration: 0.3)
}
