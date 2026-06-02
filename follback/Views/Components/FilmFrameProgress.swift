import SwiftUI

struct FilmFrameProgress: View {
    let filled: Int
    let total: Int
    @State private var appeared = false

    var body: some View {
        let safeTotal = max(1, total)
        let displayCount = min(safeTotal, 36)
        let cellWidth: CGFloat = displayCount > 24 ? 6 : 8

        HStack(spacing: 2) {
            ForEach(0..<displayCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < filled ? Color.filmAccent : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
                    .frame(width: cellWidth, height: 12)
                    .scaleEffect(appeared ? 1.0 : 0.1)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                        .delay(Double(i) * 0.02),
                        value: appeared
                    )
            }
        }
        .onAppear {
            appeared = true
        }
    }
}
