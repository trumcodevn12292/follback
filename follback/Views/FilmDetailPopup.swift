import SwiftUI
import Kingfisher

struct FilmDetailPopup: View {
    let stock: FilmStock
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Backdrop: blurred cover image fills entire screen
            backdropView
                .ignoresSafeArea()

            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Cover image
                    coverImageView
                        .padding(.horizontal, 28)

                    Spacer().frame(height: 24)

                    // Description text
                    if let description = stock.filmDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 80)
                }
            }

            // Close button "+" at top center (matching Filmer)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
            .padding(.top, 12)
        }
        .background(Color.black.ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdropView: some View {
        if let coverUrlString = stock.fullCoverUrl,
           let coverURL = URL(string: coverUrlString) {
            ZStack {
                KFImage(coverURL)
                    .requestModifier(FilmerImageAuth.shared.modifier)
                    .downsampling(size: CGSize(width: 200, height: 200))
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 50)
                    .scaleEffect(1.2)

                Color.black.opacity(0.25)
            }
        } else {
            LinearGradient(
                colors: [stock.color.opacity(0.5), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Cover Image

    @ViewBuilder
    private var coverImageView: some View {
        if let coverUrlString = stock.fullCoverUrl,
           let coverURL = URL(string: coverUrlString) {
            KFImage(coverURL)
                .requestModifier(FilmerImageAuth.shared.modifier)
                .downsampling(size: CGSize(width: 800, height: 800))
                .cacheOriginalImage()
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [stock.color.opacity(0.4), stock.accentColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 48, weight: .thin))
                        Text(stock.displayName)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.5))
                )
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// UIKit helper to make fullScreenCover background transparent
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
