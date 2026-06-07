import SwiftUI
import Kingfisher

struct RollsUniverseView: View {
    let rolls: [Roll]
    @Binding var navPath: NavigationPath

    private let columns = 4
    private let cardSize: CGFloat = 80
    private let spacing: CGFloat = 20

    @State private var stars: [StarPosition] = []
    @State private var cardPositions: [UUID: CGPoint] = [:]
    @State private var draggedCardId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var cardScales: [UUID: CGFloat] = [:]

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
        .onAppear {
            stars = (0..<40).map { _ in
                StarPosition(
                    x: CGFloat.random(in: 0...1),
                    y: CGFloat.random(in: 0...1),
                    size: CGFloat.random(in: 1...2.5),
                    baseAlpha: Double.random(in: 0.3...0.8),
                    phase: Double.random(in: 0...(2 * .pi)),
                    speed: Double.random(in: 0.15...0.4)
                )
            }
        }
    }

    // MARK: - Starfield

    private var starfield: some View {
        Canvas { context, size in
            for star in stars {
                let alpha = star.baseAlpha
                context.fill(
                    Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)),
                    with: .color(.white.opacity(alpha))
                )
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

                let settled = cardPositions[roll.id] ?? CGPoint(x: baseX, y: baseY)
                let isDragged = draggedCardId == roll.id

                let driftX = sin(time * 0.15 + phase) * 14
                let driftY = cos(time * 0.12 + phase * 1.3) * 10
                let rotation = sin(time * 0.08 + phase * 0.7) * 3
                let scale = isDragged ? (cardScales[roll.id] ?? 1.15) : (1.0 + sin(time * 0.10 + phase * 0.9) * 0.03)

                let posX = isDragged ? settled.x + driftX + dragOffset.width : settled.x + driftX
                let posY = isDragged ? settled.y + driftY + dragOffset.height : settled.y + driftY

                floatingCard(roll: roll, size: cardSize)
                    .scaleEffect(scale)
                    .shadow(color: .black.opacity(isDragged ? 0.45 : 0.2), radius: isDragged ? 18 : 6, y: isDragged ? 8 : 3)
                    .rotationEffect(.degrees(rotation))
                    .position(x: posX, y: posY)
                    .gesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { value in
                                if draggedCardId == nil {
                                    draggedCardId = roll.id
                                    withAnimation(.spring(response: 0.2)) {
                                        cardScales[roll.id] = 1.15
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                let newX = settled.x + value.translation.width
                                let newY = settled.y + value.translation.height
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    cardPositions[roll.id] = CGPoint(x: newX, y: newY)
                                    cardScales[roll.id] = 1.0
                                }
                                draggedCardId = nil
                                dragOffset = .zero
                            }
                    )
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
    let baseAlpha: Double
    let phase: Double
    let speed: Double
}
