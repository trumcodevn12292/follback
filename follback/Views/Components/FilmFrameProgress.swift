import SwiftUI

struct FilmFrameProgress: View {
    let filled: Int
    let total: Int
    @State private var appeared = false

    var body: some View {
        let safeTotal = max(1, total)
        let displayCount = min(safeTotal, 36)
        let cellWidth: CGFloat = displayCount > 24 ? 5 : 7

        HStack(spacing: 2) {
            ForEach(0..<displayCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < filled
                          ? LinearGradient(
                                colors: [Color.filmAccent, Color.filmGold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                          : LinearGradient(
                                colors: [Color.filmBorder.opacity(0.3), Color.filmBorder.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .frame(width: cellWidth, height: 14)
                    .shadow(color: i < filled ? Color.filmAccent.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
                    .scaleEffect(appeared ? 1.0 : 0.1)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                        .delay(Double(i) * 0.015),
                        value: appeared
                    )
            }
        }
        .onAppear {
            appeared = true
        }
    }
}
