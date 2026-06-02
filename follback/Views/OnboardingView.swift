import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    let pages = [
        (icon: "camera.aperture", title: "FilmVault", subtitle: "Your personal darkroom journal for analog photography"),
        (icon: "film.stack", title: "Track Every Roll", subtitle: "Log film stocks, cameras, exposure settings, and locations"),
        (icon: "photo.stack", title: "Relive the Journey", subtitle: "Attach photos, view stats, and share your story")
    ]

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageContent(index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 480)

                VStack(spacing: 28) {
                    pageIndicator

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "camera.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color.filmBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.filmAccent)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, max(24, bottomSafeArea))
            }
        }
    }

    private func pageContent(index: Int) -> some View {
        let page = pages[index]
        return VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.filmAccent.opacity(0.15), Color.filmGold.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(Color.filmAccent)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)

                Text(page.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(currentPage == i ? Color.filmAccent : Color.filmBorder)
                    .frame(width: currentPage == i ? 28 : 8, height: 8)
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
