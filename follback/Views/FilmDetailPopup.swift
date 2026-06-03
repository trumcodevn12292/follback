import SwiftUI
import Kingfisher

struct FilmDetailPopup: View {
    let stock: FilmStock
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Backdrop: blurred cover image fills entire background
            if let coverUrlString = stock.fullCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .requestModifier(FilmerImageAuth.shared.modifier)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.3).ignoresSafeArea())
            } else {
                stock.color.opacity(0.4)
                    .ignoresSafeArea()
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.3).ignoresSafeArea())
            }

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    // Cover image — large, rounded
                    if let coverUrlString = stock.fullCoverUrl,
                       let coverURL = URL(string: coverUrlString) {
                        KFImage(coverURL)
                            .requestModifier(FilmerImageAuth.shared.modifier)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                            .padding(.horizontal, 32)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [stock.color.opacity(0.4), stock.accentColor.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 280)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 56, weight: .thin))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                            .padding(.horizontal, 32)
                    }

                    // Description
                    if let description = stock.filmDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 40)
                }
            }

            // Tap anywhere to dismiss (behind scroll content)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .allowsHitTesting(true)
                .ignoresSafeArea()
                .zIndex(-1)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}
