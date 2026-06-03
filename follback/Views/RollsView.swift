import SwiftUI
import SwiftData
import Shimmer
import Combine
import CoreMotion

struct RollsView: View {
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddSheet = false
    @State private var selectedFilter: RollStatus? = nil
    @State private var appeared = false
    @State private var isLoading = true
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var editingRoll: Roll?
    @State private var filmDetailStock: FilmStock?
    @State private var rollBaseFrames: [UUID: CGRect] = [:]
    @StateObject private var physics = RollPhysicsEngine()

    private var filteredRolls: [Roll] {
        var result = rolls
        if let filter = selectedFilter {
            result = result.filter { $0.rollStatus == filter }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.filmName.lowercased().contains(query) ||
                ($0.camera?.name.lowercased().contains(query) ?? false) ||
                ($0.locationName?.lowercased().contains(query) ?? false) ||
                ($0.notes.lowercased().contains(query))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection

                        if showSearch {
                            searchBar
                        }

                        filterSection

                        if rolls.isEmpty && !isLoading {
                            emptyState
                        } else if isLoading {
                            shimmerContent
                        } else {
                            rollList
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }

                // Floating "+ New Roll" button
                Button {
                    showAddSheet = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text("New Roll")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color.filmText)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.filmSurface)
                            .overlay(
                                Capsule()
                                    .stroke(Color.filmBorder, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showAddSheet) {
                NavigationStack {
                    AddRollView()
                }
            }
            .navigationDestination(for: Roll.self) { roll in
                RollDetailView(roll: roll)
            }
            .sheet(item: $editingRoll) { roll in
                EditRollDetailsView(roll: roll)
            }
            .fullScreenCover(item: $filmDetailStock) { stock in
                FilmDetailPopup(stock: stock) {
                    filmDetailStock = nil
                }
                .background(ClearBackgroundView())
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        isLoading = false
                        appeared = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                triggerShakeAnimation()
            }
            .onChange(of: physics.mode) { _, newMode in
                if newMode == .idle {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .onDisappear {
                physics.reset()
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private func triggerShakeAnimation() {
        switch physics.mode {
        case .idle:
            // First shake: DROP — hand the rolls to the physics engine and let gravity work.
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

            let screenW = UIScreen.main.bounds.width
            let screenH = UIScreen.main.bounds.height
            let insets = safeAreaInsets()
            // Real screen-box walls (global coords). Top stays clear of the notch.
            let topWall = insets.top + 22            // a comfortable gap below the notch
            let bottomWall = screenH - max(insets.bottom + 56, 96) // above the tab bar
            let pileStep: CGFloat = 16
            let count = filteredRolls.count

            var bodies: [RollPhysicsEngine.Spec] = []
            for (index, roll) in filteredRolls.enumerated() {
                let slot = count - 1 - index // bottom-most card settles lowest
                let floor: CGFloat
                let ceil: CGFloat
                let minX: CGFloat
                let maxX: CGFloat
                if let frame = rollBaseFrames[roll.id] {
                    // Offsets that put the card's edges exactly on each wall (with pile stagger).
                    floor = (bottomWall - CGFloat(slot) * pileStep) - frame.maxY
                    ceil = (topWall + CGFloat(slot) * pileStep) - frame.minY
                    minX = 12 - frame.minX
                    maxX = screenW - 12 - frame.maxX
                } else {
                    floor = max(0, (bottomWall - CGFloat(slot) * pileStep) - 140 - (CGFloat(index) * 150 + 220))
                    ceil = topWall - screenH
                    minX = -screenW
                    maxX = screenW
                }
                bodies.append(.init(
                    id: roll.id,
                    floor: max(floor, 0),
                    ceil: min(ceil, 0),
                    minX: min(minX, 0),
                    maxX: max(maxX, 0)
                ))
            }
            physics.drop(bodies)

        case .falling:
            // Second shake: rewind — spring everything back to its original spot.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            physics.returnHome()

        case .returning:
            break // ignore shakes mid-rewind
        }
    }

    private func safeAreaInsets() -> UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        return window?.safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }

    private func rollFrameReader(for roll: Roll) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    if physics.mode == .idle {
                        rollBaseFrames[roll.id] = geo.frame(in: .global)
                    }
                }
                .onChange(of: geo.frame(in: .global)) { _, newValue in
                    if physics.mode == .idle {
                        rollBaseFrames[roll.id] = newValue
                    }
                }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image("AppIconSmall")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text("FILMVAULT")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color.filmText)
                    .kerning(1.5)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSearch.toggle()
                    if !showSearch { searchText = "" }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(showSearch ? Color.filmAccent.opacity(0.15) : Color.filmSurface)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(.easeOut(duration: 0.3), value: appeared)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(Color.filmTertiary)
            TextField("Search rolls...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(Color.filmText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.filmSurface)
        )
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }

    // MARK: - Filters

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(nil, label: "All", count: rolls.count)
                filterPill(.inProgress, label: "Active", count: rolls.filter { $0.rollStatus == .inProgress }.count)
                filterPill(.completed, label: "Completed", count: rolls.filter { $0.rollStatus == .completed }.count)
                filterPill(.developed, label: "Developed", count: rolls.filter { $0.rollStatus == .developed }.count)
                filterPill(.archived, label: "Archived", count: rolls.filter { $0.rollStatus == .archived }.count)
            }
            .padding(.horizontal, 20)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.05), value: appeared)
    }

    private func filterPill(_ status: RollStatus?, label: String, count: Int) -> some View {
        let isActive = selectedFilter == status
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedFilter = (selectedFilter == status) ? nil : status
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
            }
            .foregroundColor(isActive ? Color.filmBackground : Color.filmSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.filmAccent : Color.filmSurface)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : Color.filmBorder.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Roll List

    private var rollList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(filteredRolls.enumerated()), id: \.element.id) { index, roll in
                NavigationLink(value: roll) {
                    RollCard(
                        roll: roll,
                        onDelete: { deleteRoll(roll) },
                        onArchive: { archiveRoll(roll) },
                        onEditDetails: { editingRoll = roll },
                        onCoverTap: { stock in filmDetailStock = stock }
                    )
                }
                .buttonStyle(.plain)
                .background(rollFrameReader(for: roll))
                .opacity(appeared ? 1 : 0)
                .offset(
                    x: physics.bodies[roll.id]?.x ?? 0,
                    y: (appeared ? 0 : 18) + (physics.bodies[roll.id]?.y ?? 0)
                )
                .rotationEffect(.degrees(physics.bodies[roll.id]?.angle ?? 0))
                .scaleEffect(appeared ? 1 : 0.97)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.05),
                    value: appeared
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(Color.filmTertiary)

            VStack(spacing: 6) {
                Text("No rolls yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.filmText)
                Text("Start your analog journey")
                    .font(.system(size: 15))
                    .foregroundColor(Color.filmTertiary)
            }
        }
        .padding(.top, 80)
    }

    // MARK: - Shimmer

    private var shimmerContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.filmSurface)
                    .frame(height: 120)
                    .shimmering(
                        gradient: Gradient(colors: [.clear, Color.filmAccent.opacity(0.04), .clear]),
                        bandSize: 0.5
                    )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func deleteRoll(_ roll: Roll) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            modelContext.delete(roll)
            try? modelContext.save()
            NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        }
    }

    private func archiveRoll(_ roll: Roll) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            roll.updateStatus(.archived)
            try? modelContext.save()
            NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        }
    }
}

// MARK: - Roll Physics Engine

/// A small per-card physics simulation driving the shake easter egg.
///
/// Each roll is a body with position/velocity/angle. A display link integrates
/// gravity (direction read live from CoreMotion) every frame, so rolls fall
/// naturally, bounce off the screen floor and side walls, settle into a pile,
/// and then slide along those edges when the phone is tilted. A second shake
/// switches to `returning` mode and springs every body back to its origin.
final class RollPhysicsEngine: ObservableObject {

    enum Mode: Equatable { case idle, falling, returning }

    struct Body {
        var x: CGFloat = 0          // horizontal offset from layout position
        var y: CGFloat = 0          // vertical offset (down is positive)
        var vx: CGFloat = 0
        var vy: CGFloat = 0
        var angle: Double = 0       // degrees
        var angularVelocity: Double = 0
        var floor: CGFloat = 0      // max y (bottom wall, resting pile level)
        var ceil: CGFloat = 0       // min y (top wall, just below the notch)
        var minX: CGFloat = 0       // left bound for x
        var maxX: CGFloat = 0       // right bound for x
    }

    struct Spec {
        let id: UUID
        let floor: CGFloat
        let ceil: CGFloat
        let minX: CGFloat
        let maxX: CGFloat
    }

    @Published private(set) var bodies: [UUID: Body] = [:]
    @Published private(set) var mode: Mode = .idle

    private var order: [UUID] = []
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private let motion = CMMotionManager()
    private var gravityX: CGFloat = 0
    private var gravityY: CGFloat = -1 // upright default so it works without sensors

    // Tunables (points / seconds).
    private let gravityScale: CGFloat = 2600
    private let restitution: CGFloat = 0.45
    private let floorFriction: CGFloat = 0.88
    private let returnStiffness: CGFloat = 200
    private let returnDamping: CGFloat = 26
    private let notchSpinZone: CGFloat = 60   // distance from top wall that triggers spin
    private let notchSpinSpeed: Double = 320   // deg/s twirl speed near the notch

    // MARK: Public control

    func drop(_ specs: [Spec]) {
        order = specs.map(\.id)
        var newBodies: [UUID: Body] = [:]
        for spec in specs {
            var body = Body()
            body.floor = spec.floor
            body.ceil = spec.ceil
            body.minX = spec.minX
            body.maxX = spec.maxX
            body.vx = CGFloat.random(in: -40...40)
            body.angularVelocity = Double.random(in: -60...60)
            newBodies[spec.id] = body
        }
        bodies = newBodies
        mode = .falling
        startMotion()
        startLink()
    }

    func returnHome() {
        guard mode == .falling else { return }
        mode = .returning
        stopMotion() // gravity no longer needed while rewinding
        startLink()
    }

    func reset() {
        mode = .idle
        stopLink()
        stopMotion()
        bodies = [:]
        order = []
    }

    // MARK: CoreMotion

    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }
            self.gravityX = CGFloat(gravity.x)
            self.gravityY = CGFloat(gravity.y)
        }
    }

    private func stopMotion() {
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        gravityX = 0
        gravityY = -1
    }

    // MARK: Display link

    private func startLink() {
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        let dt = CGFloat(min(link.timestamp - lastTimestamp, 1.0 / 30.0)) // clamp big hitches
        lastTimestamp = link.timestamp
        guard dt > 0 else { return }

        switch mode {
        case .falling: stepFalling(dt)
        case .returning: stepReturning(dt)
        case .idle: stopLink()
        }
    }

    private func stepFalling(_ dt: CGFloat) {
        // Screen-space gravity: x follows tilt, y is positive downward.
        let ax = gravityX * gravityScale
        let ay = -gravityY * gravityScale

        var updated = bodies
        for id in order {
            guard var b = updated[id] else { continue }

            b.vx += ax * dt
            b.vy += ay * dt
            b.x += b.vx * dt
            b.y += b.vy * dt

            // Side walls.
            if b.x < b.minX {
                b.x = b.minX
                b.vx = -b.vx * restitution
                b.angularVelocity += Double(b.vy) * 0.03
            } else if b.x > b.maxX {
                b.x = b.maxX
                b.vx = -b.vx * restitution
                b.angularVelocity -= Double(b.vy) * 0.03
            }

            // Top wall (just below the notch): bounce off it, never overlap the notch.
            if b.y <= b.ceil {
                b.y = b.ceil
                if b.vy < -40 {
                    b.vy = -b.vy * restitution
                    b.angularVelocity += Double(b.vx) * 0.04
                } else {
                    b.vy = 0
                }
                b.vx *= floorFriction
            }

            // Floor (pile level): bounce when hitting fast, otherwise rest + friction.
            if b.y >= b.floor {
                b.y = b.floor
                if b.vy > 40 {
                    b.vy = -b.vy * restitution
                    b.angularVelocity += Double(b.vx) * 0.04
                } else {
                    b.vy = 0
                }
                b.vx *= floorFriction
                b.angularVelocity *= floorFriction
                if abs(b.vx) < 1 { b.vx = 0 }
                if abs(b.angularVelocity) < 1 { b.angularVelocity = 0 }
            }

            // Spin near the notch: when the phone is flipped (gravity pulling up) and a
            // card hovers close to the top wall, make it twirl instead of pressing in.
            let nearNotch = (b.y - b.ceil) < notchSpinZone
            if nearNotch && ay < 0 {
                let target = notchSpinSpeed * (b.vx >= 0 ? 1 : -1)
                b.angularVelocity += (target - b.angularVelocity) * 0.1
            }

            b.angle += b.angularVelocity * dt
            updated[id] = b
        }
        bodies = updated
    }

    private func stepReturning(_ dt: CGFloat) {
        var updated = bodies
        var allHome = true
        for id in order {
            guard var b = updated[id] else { continue }

            // Critically-damped-ish spring back to the origin.
            let ax = -returnStiffness * b.x - returnDamping * b.vx
            let ay = -returnStiffness * b.y - returnDamping * b.vy
            b.vx += ax * dt
            b.vy += ay * dt
            b.x += b.vx * dt
            b.y += b.vy * dt
            b.angle += b.angularVelocity * dt
            b.angularVelocity *= 0.82
            b.angle *= 0.82

            let settled = abs(b.x) < 0.5 && abs(b.y) < 0.5 &&
                abs(b.vx) < 6 && abs(b.vy) < 6 && abs(b.angle) < 0.5
            if settled {
                b = Body(x: 0, y: 0, vx: 0, vy: 0, angle: 0, angularVelocity: 0,
                         floor: b.floor, ceil: b.ceil, minX: b.minX, maxX: b.maxX)
            } else {
                allHome = false
            }
            updated[id] = b
        }
        bodies = updated
        if allHome { reset() }
    }

    deinit {
        displayLink?.invalidate()
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
    }
}
