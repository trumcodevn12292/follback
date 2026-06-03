import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var pulseAmount: CGFloat = 1.0

    let pages = [
        (icon: "camera.aperture", title: "FilmVault", subtitle: "Your personal darkroom journal for analog photography", accent: Color.filmAccent),
        (icon: "film.stack", title: "Track Every Roll", subtitle: "Log film stocks, cameras, exposure settings, and locations", accent: Color.filmGold),
        (icon: "photo.stack", title: "Relive the Journey", subtitle: "Attach photos, view stats, and share your story", accent: Color.filmCopper)
    ]

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            backgroundOrbs

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageContent(index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 500)

                VStack(spacing: 24) {
                    pageIndicator

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            onComplete()
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 10) {
                            Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color.filmBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(Color.filmAccent)
                                .shadow(color: Color.filmAccent.opacity(0.3), radius: 12, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    if currentPage < pages.count - 1 {
                        Button {
                            onComplete()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, max(28, bottomSafeArea))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulseAmount = 1.15
            }
        }
    }

    private var backgroundOrbs: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.filmAccent.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -80, y: -200)
                .scaleEffect(pulseAmount)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.filmGold.opacity(0.06), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: 100, y: 150)
                .scaleEffect(pulseAmount * 0.9)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.filmCopper.opacity(0.04), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: -50, y: 300)
                .scaleEffect(pulseAmount * 1.1)
        }
    }

    private func pageContent(index: Int) -> some View {
        let page = pages[index]
        return VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.accent.opacity(0.15), page.accent.opacity(0.02)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseAmount)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [page.accent.opacity(0.3), page.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.accent, page.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)

                Text(page.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(5)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(
                        currentPage == i
                        ? Color.filmAccent
                        : Color.filmBorder.opacity(0.4)
                    )
                    .frame(width: currentPage == i ? 32 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.bottom ?? 0
    }
}
