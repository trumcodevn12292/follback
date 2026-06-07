import SwiftUI
import Kingfisher

struct RollsUniverseView: View {
    let rolls: [Roll]
    @Binding var navPath: NavigationPath

    private let columns = 4
    private let cardSize: CGFloat = 76
    private let spacing: CGFloat = 16

    private var gridSize: (cols: Int, rows: Int) {
        let cols = min(columns, max(1, rolls.count))
        let rows = (rolls.count + cols - 1) / cols
        return (cols, rows)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                starfield
                floatingCovers(time: time)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Starfield

    private var starfield: some View {
        let stars = (0..<60).map { _ in
            StarPosition(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...2.5),
                opacity: Double.random(in: 0.3...0.9),
                phase: Double.random(in: 0...(2 * .pi)),
                speed: Double.random(in: 0.5...2.0)
            )
        }

        return TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for star in stars {
                    let twinkle = sin(t * star.speed + star.phase) * 0.5 + 0.5
                    let alpha = star.opacity * (0.5 + twinkle * 0.5)
                    context.fill(
                        Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Floating Covers

    private func floatingCovers(time: TimeInterval) -> some View {
        let cols = gridSize.cols
        let rows = gridSize.rows

        let totalW = CGFloat(cols) * cardSize + CGFloat(cols - 1) * spacing
        let totalH = CGFloat(rows) * cardSize + CGFloat(rows - 1) * spacing

        return GeometryReader { geo in
            let originX = (geo.size.width - totalW) / 2 + cardSize / 2
            let originY = (geo.size.height - totalH) / 2 + cardSize / 2

            ForEach(Array(rolls.enumerated()), id: \.element.id) { index, roll in
                let col = index % cols
                let row = index / cols
                let phase = Double(index) * 1.7

                let baseX = originX + CGFloat(col) * (cardSize + spacing)
                let baseY = originY + CGFloat(row) * (cardSize + spacing)

                let driftX = sin(time * 0.25 + phase) * 18
                let driftY = cos(time * 0.20 + phase * 1.3) * 14
                let rotation = sin(time * 0.12 + phase * 0.7) * 4
                let scale = 1.0 + sin(time * 0.18 + phase * 0.9) * 0.04

                floatingCard(roll: roll, size: cardSize)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .position(x: baseX + driftX, y: baseY + driftY)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        navPath.append(roll)
                    }
            }
        }
    }

    // MARK: - Card

    private func floatingCard(roll: Roll, size: CGFloat) -> some View {
        let stock = matchingFilmStock(for: roll)
        let coverUrl = stock?.githubCoverUrl

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.filmSurface)
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if let url = coverUrl, let imageUrl = URL(string: url) {
                        KFImage(imageUrl)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(Color.filmTertiary)
                            Text(String(roll.filmName.prefix(8)))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(Color.filmSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.filmBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private func matchingFilmStock(for roll: Roll) -> FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }
}

private struct StarPosition {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let phase: Double
    let speed: Double
}
