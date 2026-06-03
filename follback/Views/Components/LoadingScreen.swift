import SwiftUI

struct LoadingScreen: View {
    @State private var filmRotation: Double = 0
    @State private var filmScale: CGFloat = 0.6
    @State private var textOpacity: Double = 0
    @State private var stripOffset: CGFloat = 200
    @State private var dotPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            Color.filmBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated film reel icon
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.filmAccent.opacity(0.8),
                                    Color.filmAccent.opacity(0.2),
                                    Color.filmAccent.opacity(0.0),
                                    Color.filmAccent.opacity(0.8)
                                ]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(filmRotation))

                    // Inner icon
                    Image(systemName: "film")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color.filmAccent)
                        .scaleEffect(filmScale)
                }

                // App name
                VStack(spacing: 8) {
                    Text("FilmVault")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color.filmText)
                        .opacity(textOpacity)

                    // Loading dots
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.filmAccent)
                                .frame(width: 5, height: 5)
                                .scaleEffect(dotScale(for: index))
                                .opacity(dotOpacity(for: index))
                        }
                    }
                    .opacity(textOpacity)
                }

                Spacer()
                Spacer()
            }

            // Film strip decoration (bottom)
            VStack {
                Spacer()
                filmStrip
                    .offset(x: stripOffset)
                    .opacity(0.15)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                filmRotation = 360
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                filmScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                stripOffset = 0
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                dotPhase = 1
            }
        }
    }

    private func dotScale(for index: Int) -> CGFloat {
        let phase = (dotPhase + CGFloat(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.6 + 0.4 * sin(phase * .pi)
    }

    private func dotOpacity(for index: Int) -> Double {
        let phase = (dotPhase + CGFloat(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.4 + 0.6 * sin(Double(phase) * .pi)
    }

    private var filmStrip: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.filmAccent)
                    .frame(width: 28, height: 20)
            }
        }
        .padding(.bottom, 40)
    }
}
