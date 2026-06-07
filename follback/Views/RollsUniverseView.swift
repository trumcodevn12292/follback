import SwiftUI
import Kingfisher

private struct CardConfig {
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
    @State private var cardImages: [UUID: UIImage] = [:]

    // Drag state
    @State private var draggedCardId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartSettled: CGPoint = .zero
    @State private var dragScale: CGFloat = 1.0
    @State private var draggedCardStartLocation: CGPoint = .zero

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            canvasContent(time: time)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if draggedCardId == nil {
                                if let config = cardAt(point: value.startLocation, time: time) {
                                    draggedCardId = config.id
                                    dragStartSettled = cardPositions[config.id] ?? config.basePos
                                    draggedCardStartLocation = value.startLocation
                                    dragScale = 1.15
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                            if draggedCardId != nil {
                                dragOffset = CGSize(
                                    width: value.location.x - draggedCardStartLocation.x,
                                    height: value.location.y - draggedCardStartLocation.y
                                )
                            }
                        }
                        .onEnded { value in
                            guard let id = draggedCardId else { return }
                            let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)

                            if distance < 5 {
                                if let config = configs.first(where: { $0.id == id }) {
                                    navPath.append(config.roll)
                                }
                            } else {
                                let newX = dragStartSettled.x + value.translation.width
                                let newY = dragStartSettled.y + value.translation.height
                                cardPositions[id] = CGPoint(x: newX, y: newY)
                            }

                            draggedCardId = nil
                            dragOffset = .zero
                            dragScale = 1.0
                        }
                )
        }
        .onAppear {
            setupStars()
            setupConfigs()
            loadImages()
        }
        .onChange(of: rolls.count) { _, _ in
            setupConfigs()
            loadImages()
        }
    }

    private func canvasContent(time: TimeInterval) -> some View {
        Canvas { context, size in
            for star in stars {
                context.fill(
                    Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)),
                    with: .color(.white.opacity(star.baseAlpha))
                )
            }

            for config in configs {
                let settled = cardPositions[config.id] ?? config.basePos
                let isDragged = draggedCardId == config.id

                let driftX = sin(time * 0.15 + config.phase) * 14
                let driftY = cos(time * 0.12 + config.phase * 1.3) * 10

                let posX = settled.x + driftX + (isDragged ? dragOffset.width : 0)
                let posY = settled.y + driftY + (isDragged ? dragOffset.height : 0)

                let half = cardSize / 2
                let rect = CGRect(x: posX - half, y: posY - half, width: cardSize, height: cardSize)
                let cardPath = RoundedRectangle(cornerRadius: 10, style: .continuous).path(in: rect)

                // Shadow
                let shadowPath = RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .path(in: CGRect(x: posX - half + 4, y: posY - half + 6, width: cardSize, height: cardSize))
                context.fill(shadowPath, with: .color(.black.opacity(isDragged ? 0.35 : 0.18)))

                // Card background
                context.fill(cardPath, with: .color(Color.filmSurface))

                // Card image
                if let uiImage = cardImages[config.id] {
                    let sc = isDragged ? dragScale : (1.0 + sin(time * 0.10 + config.phase * 0.9) * 0.03)
                    context.drawLayer { ctx in
                        let angleDeg = isDragged ? 0 : sin(time * 0.08 + config.phase * 0.7)
                        ctx.translateBy(x: rect.midX, y: rect.midY)
                        ctx.rotate(by: Angle(degrees: angleDeg))
                        ctx.scaleBy(x: sc, y: sc)
                        ctx.translateBy(x: -rect.midX, y: -rect.midY)
                        ctx.clip(to: cardPath)
                        ctx.draw(Image(uiImage: uiImage), in: rect)
                    }
                }

                // Border
                context.stroke(cardPath, with: .color(Color.filmBorder), lineWidth: 0.5)

                // Drag overlay
                if isDragged {
                    context.fill(cardPath, with: .color(.black.opacity(0.06)))
                }
            }
        }
    }

    // MARK: - Hit Testing

    private func cardAt(point: CGPoint, time: TimeInterval) -> CardConfig? {
        for config in configs.reversed() {
            let settled = cardPositions[config.id] ?? config.basePos
            let driftX = sin(time * 0.15 + config.phase) * 14
            let driftY = cos(time * 0.12 + config.phase * 1.3) * 10
            let cx = settled.x + driftX
            let cy = settled.y + driftY
            let half = cardSize / 2 + 6
            if abs(point.x - cx) <= half && abs(point.y - cy) <= half {
                return config
            }
        }
        return nil
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

    private func loadImages() {
        for config in configs {
            guard cardImages[config.id] == nil else { continue }
            let stock = matchingFilmStock(for: config.roll)
            guard let urlString = stock?.githubCoverUrl, let url = URL(string: urlString) else { continue }
            KingfisherManager.shared.retrieveImage(with: url) { result in
                if case .success(let value) = result {
                    Task { @MainActor in
                        cardImages[config.id] = value.image
                    }
                }
            }
        }
    }

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
