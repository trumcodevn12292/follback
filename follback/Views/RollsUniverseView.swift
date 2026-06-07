import SwiftUI
import Kingfisher

private struct CardConfig: Identifiable {
    let id: UUID
    let roll: Roll
    var basePos: CGPoint
    let phase: Double
}

struct RollsUniverseView: View {
    let rolls: [Roll]
    @Binding var navPath: NavigationPath

    private let columns = 4
    private let cardSize: CGFloat = 80
    private let spacing: CGFloat = 20

    @State private var stars: [StarPosition] = []
    @State private var configs: [CardConfig] = []
    @State private var cardPositions: [UUID: CGPoint] = [:]
    @State private var draggedCardId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var cardScales: [UUID: CGFloat] = [:]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                Canvas { context, size in
                    for star in stars {
                        context.fill(
                            Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)),
                            with: .color(.white.opacity(star.baseAlpha))
                        )
                    }
                }

                ForEach(configs) { config in
                    let settled = cardPositions[config.id] ?? config.basePos
                    let isDragged = draggedCardId == config.id

                    let driftX = sin(time * 0.15 + config.phase) * 14
                    let driftY = cos(time * 0.12 + config.phase * 1.3) * 10
                    let rotation = sin(time * 0.08 + config.phase * 0.7) * 3
                    let scale = isDragged ? (cardScales[config.id] ?? 1.15) : (1.0 + sin(time * 0.10 + config.phase * 0.9) * 0.03)

                    let offsetX = driftX + (isDragged ? dragOffset.width : 0)
                    let offsetY = driftY + (isDragged ? dragOffset.height : 0)

                    floatingCard(roll: config.roll)
                        .scaleEffect(scale)
                        .shadow(color: .black.opacity(isDragged ? 0.45 : 0.2), radius: isDragged ? 18 : 6, y: isDragged ? 8 : 3)
                        .rotationEffect(.degrees(rotation))
                        .position(x: settled.x, y: settled.y)
                        .offset(x: offsetX, y: offsetY)
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    if draggedCardId == nil {
                                        draggedCardId = config.id
                                        withAnimation(.spring(response: 0.2)) {
                                            cardScales[config.id] = 1.15
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    let newX = settled.x + value.translation.width
                                    let newY = settled.y + value.translation.height
                                    cardPositions[config.id] = CGPoint(x: newX, y: newY)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        cardScales[config.id] = 1.0
                                    }
                                    draggedCardId = nil
                                    dragOffset = .zero
                                }
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            navPath.append(config.roll)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            setupStars()
            setupConfigs()
        }
        .onChange(of: rolls.count) { _, _ in setupConfigs() }
    }

    // MARK: - Setup

    private func setupStars() {
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

    private func setupConfigs() {
        guard !rolls.isEmpty else { configs = []; return }
        let cols = min(columns, max(1, rolls.count))
        let rows = (rolls.count + cols - 1) / cols
        let totalW = CGFloat(cols) * cardSize + CGFloat(cols - 1) * spacing
        let totalH = CGFloat(rows) * cardSize + CGFloat(rows - 1) * spacing

        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let originX = (screenW - totalW) / 2 + cardSize / 2
        let originY = (screenH - totalH) / 2 + cardSize / 2

        configs = rolls.enumerated().map { index, roll in
            let col = index % cols
            let row = index / cols
            return CardConfig(
                id: roll.id,
                roll: roll,
                basePos: CGPoint(
                    x: originX + CGFloat(col) * (cardSize + spacing),
                    y: originY + CGFloat(row) * (cardSize + spacing)
                ),
                phase: Double(index) * 1.7
            )
        }
    }

    // MARK: - Card

    private func floatingCard(roll: Roll) -> some View {
        let stock = matchingFilmStock(for: roll)
        let coverUrl = stock?.githubCoverUrl

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.filmSurface)
            .frame(width: cardSize, height: cardSize)
            .overlay(
                Group {
                    if let url = coverUrl, let imageUrl = URL(string: url) {
                        KFImage(imageUrl)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardSize, height: cardSize)
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
