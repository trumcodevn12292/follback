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
    @State private var showFilterSheet = false
    @State private var sortOption: RollSortOption = .newest
    @State private var filterFilm: String? = nil
    @State private var filterCamera: String? = nil
    @State private var filterLab: String? = nil
    @State private var filterYear: Int? = nil
    @State private var filterPushPull: PushPullFilter? = nil
    @State private var editingRoll: Roll?
    @State private var filmDetailStock: FilmStock?
    @State private var rollBaseFrames: [UUID: CGRect] = [:]
    @StateObject private var physics = RollPhysicsEngine()
    @State private var navPath = NavigationPath()
    @ObservedObject private var deepLink = WidgetDeepLink.shared

    // A roll can belong to several filter tabs at once:
    // - Active: still shooting (not full) and not archived — includes empty rolls.
    // - Developed: has at least one shot frame and not archived.
    // - Completed: all frames shot and not archived.
    // - Archived: archived only.
    private func roll(_ roll: Roll, matches filter: RollStatus) -> Bool {
        if roll.rollStatus == .archived { return filter == .archived }
        switch filter {
        case .inProgress: return roll.filledFrames < roll.capacity
        case .completed:  return roll.filledFrames >= roll.capacity
        case .developed:  return roll.filledFrames >= 1
        case .archived:   return false
        }
    }

    private func count(for filter: RollStatus) -> Int {
        rolls.filter { roll($0, matches: filter) }.count
    }

    private func cameraLabel(_ camera: Camera?) -> String? {
        guard let camera else { return nil }
        let label = "\(camera.brand) \(camera.name)".trimmingCharacters(in: .whitespaces)
        return label.isEmpty ? nil : label
    }

    private var distinctFilms: [String] {
        Array(Set(rolls.map { $0.filmName }.filter { !$0.isEmpty })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var distinctCameras: [String] {
        Array(Set(rolls.compactMap { cameraLabel($0.camera) })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var distinctLabs: [String] {
        Array(Set(rolls.compactMap { roll -> String? in
            let s = (roll.labName ?? "").trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var distinctYears: [Int] {
        Array(Set(rolls.map { Calendar.current.component(.year, from: $0.startDate) })).sorted(by: >)
    }

    var activeAdvancedCount: Int {
        var n = 0
        if filterFilm != nil { n += 1 }
        if filterCamera != nil { n += 1 }
        if filterLab != nil { n += 1 }
        if filterYear != nil { n += 1 }
        if filterPushPull != nil { n += 1 }
        if sortOption != .newest { n += 1 }
        return n
    }

    func clearAdvancedFilters() {
        filterFilm = nil
        filterCamera = nil
        filterLab = nil
        filterYear = nil
        filterPushPull = nil
        sortOption = .newest
    }

    private var filteredRolls: [Roll] {
        var result = rolls
        if let filter = selectedFilter {
            result = result.filter { roll($0, matches: filter) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.filmName.lowercased().contains(query) ||
                ($0.camera?.name.lowercased().contains(query) ?? false) ||
                ($0.camera?.brand.lowercased().contains(query) ?? false) ||
                ($0.labName?.lowercased().contains(query) ?? false) ||
                ($0.locationName?.lowercased().contains(query) ?? false) ||
                ($0.notes.lowercased().contains(query))
            }
        }
        if let film = filterFilm {
            result = result.filter { $0.filmName == film }
        }
        if let cam = filterCamera {
            result = result.filter { cameraLabel($0.camera) == cam }
        }
        if let lab = filterLab {
            result = result.filter { ($0.labName ?? "").trimmingCharacters(in: .whitespaces) == lab }
        }
        if let year = filterYear {
            result = result.filter { Calendar.current.component(.year, from: $0.startDate) == year }
        }
        if let pp = filterPushPull {
            result = result.filter {
                switch pp {
                case .pushed: return $0.pushPull > 0
                case .pulled: return $0.pushPull < 0
                case .box:    return $0.pushPull == 0
                }
            }
        }
        switch sortOption {
        case .newest:    result.sort { $0.startDate > $1.startDate }
        case .oldest:    result.sort { $0.startDate < $1.startDate }
        case .mostShot:  result.sort { $0.filledFrames > $1.filledFrames }
        case .leastShot: result.sort { $0.filledFrames < $1.filledFrames }
        case .nameAZ:    result.sort { $0.filmName.localizedCaseInsensitiveCompare($1.filmName) == .orderedAscending }
        }
        return result
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection

                        if showSearch {
                            searchBar
                        }

                        filterSection

                        if activeAdvancedCount > 0 {
                            activeFilterSummary
                        }

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
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddRollView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(for: Roll.self) { roll in
                RollDetailView(roll: roll)
            }
            .sheet(item: $editingRoll) { roll in
                EditRollDetailsView(roll: roll)
            }
            .sheet(isPresented: $showFilterSheet) {
                RollFilterSheet(
                    sortOption: $sortOption,
                    filterFilm: $filterFilm,
                    filterCamera: $filterCamera,
                    filterLab: $filterLab,
                    filterYear: $filterYear,
                    filterPushPull: $filterPushPull,
                    films: distinctFilms,
                    cameras: distinctCameras,
                    labs: distinctLabs,
                    years: distinctYears,
                    resultCount: filteredRolls.count
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                    openPendingRollIfNeeded()
                }
            }
            .onChange(of: deepLink.pendingRollID) { _, _ in
                openPendingRollIfNeeded()
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

    private func openPendingRollIfNeeded() {
        guard let id = deepLink.pendingRollID,
              let target = rolls.first(where: { $0.id.uuidString == id }) else { return }
        deepLink.pendingRollID = nil
        navPath = NavigationPath()
        navPath.append(target)
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

            HStack(spacing: 10) {
                Button {
                    showFilterSheet = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(activeAdvancedCount > 0 ? Color.filmAccent : Color.filmText)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(activeAdvancedCount > 0 ? Color.filmAccent.opacity(0.15) : Color.filmSurface)
                            )
                        if activeAdvancedCount > 0 {
                            Text("\(activeAdvancedCount)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color.filmBackground)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Circle().fill(Color.filmAccent))
                                .offset(x: 3, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)

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
                filterPill(.inProgress, label: "Active", count: count(for: .inProgress))
                filterPill(.completed, label: "Completed", count: count(for: .completed))
                filterPill(.developed, label: "Developed", count: count(for: .developed))
                filterPill(.archived, label: "Archived", count: count(for: .archived))
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
                Text(LocalizedStringKey(label))
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

    // MARK: - Active advanced filters summary

    private var activeFilterSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if sortOption != .newest {
                    summaryChip(icon: "arrow.up.arrow.down", text: NSLocalizedString(sortOption.labelKey, comment: "")) {
                        sortOption = .newest
                    }
                }
                if let film = filterFilm {
                    summaryChip(icon: "film", text: film) { filterFilm = nil }
                }
                if let cam = filterCamera {
                    summaryChip(icon: "camera", text: cam) { filterCamera = nil }
                }
                if let lab = filterLab {
                    summaryChip(icon: "flask", text: lab) { filterLab = nil }
                }
                if let year = filterYear {
                    summaryChip(icon: "calendar", text: "\(year)") { filterYear = nil }
                }
                if let pp = filterPushPull {
                    summaryChip(icon: "plusminus", text: NSLocalizedString(pp.labelKey, comment: "")) { filterPushPull = nil }
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        clearAdvancedFilters()
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    Text("Clear all")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.filmAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }

    private func summaryChip(icon: String, text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { onRemove() }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(Color.filmText)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.filmAccent.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(Color.filmAccent.opacity(0.3), lineWidth: 0.5)
        )
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteRoll(roll)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        archiveRoll(roll)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(Color.filmTertiary)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        duplicateRoll(roll)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(Color.filmAccent)
                }
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

    private func duplicateRoll(_ roll: Roll) {
        let newRoll = Roll(
            filmName: roll.filmName,
            camera: roll.camera,
            capacity: roll.capacity,
            iso: roll.iso,
            format: roll.filmFormat,
            evCompensation: roll.evCompensation,
            pushPull: roll.pushPull,
            startDate: Date(),
            locationName: roll.locationName,
            labName: roll.labName
        )
        newRoll.filmCost = roll.filmCost
        newRoll.devCost = roll.devCost
        newRoll.notes = roll.notes
        modelContext.insert(newRoll)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
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
        var restAngle: Double = 0   // small natural lean when settled
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
    private let gravityScale: CGFloat = 3200
    private let restitution: CGFloat = 0.4
    private let floorFriction: CGFloat = 0.9
    private let returnStiffness: CGFloat = 200
    private let returnDamping: CGFloat = 26
    private let leanPerSpeed: Double = 1.0 / 24.0 // degrees of lean per pt/s of slide
    private let maxLean: Double = 16              // cap the slide lean
    private let notchSpinZone: CGFloat = 70       // distance from top wall that triggers spin
    private let notchSpinSpeed: Double = 360      // deg/s twirl speed near the notch

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
            body.vx = CGFloat.random(in: -25...25)
            body.restAngle = Double.random(in: -6...6) // messy, natural pile
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
        let flipped = gravityY > 0.4 // phone clearly upside down

        var updated = bodies
        for id in order {
            guard var b = updated[id] else { continue }

            // Integrate translation.
            b.vx += ax * dt
            b.vy += ay * dt
            b.x += b.vx * dt
            b.y += b.vy * dt

            // Side walls — slide and bounce, no spin.
            if b.x < b.minX {
                b.x = b.minX
                b.vx = -b.vx * restitution
            } else if b.x > b.maxX {
                b.x = b.maxX
                b.vx = -b.vx * restitution
            }

            // Top wall (just below the notch): bounce, never overlap the notch.
            if b.y <= b.ceil {
                b.y = b.ceil
                b.vy = b.vy < -40 ? -b.vy * restitution : 0
                b.vx *= floorFriction
            }

            // Bottom wall (pile level): bounce when fast, otherwise rest + friction.
            if b.y >= b.floor {
                b.y = b.floor
                b.vy = b.vy > 40 ? -b.vy * restitution : 0
                b.vx *= floorFriction
                if abs(b.vx) < 1 { b.vx = 0 }
            }

            // Rotation. Calm by default: a card leans "downhill" in the direction the
            // phone is tilted (so left/right tilts read as a gentle, settled slope) plus
            // a touch of lean from how fast it is sliding, easing smoothly to that angle.
            // Only near the notch, and only when the phone is clearly flipped, do cards
            // break into a continuous twirl.
            let nearNotch = (b.y - b.ceil) < notchSpinZone
            if flipped && nearNotch {
                let dir: Double = b.angularVelocity >= 0 ? 1 : -1
                b.angularVelocity += (notchSpinSpeed * dir - b.angularVelocity) * 0.08
                b.angle += b.angularVelocity * dt
            } else {
                let downhill = Double(gravityX) * 18                 // tilt-driven slope
                let slideLean = Double(b.vx) * leanPerSpeed * 0.5     // a little extra while moving
                let lean = max(-maxLean, min(maxLean, downhill + slideLean))
                let target = b.restAngle + lean
                b.angle += (target - b.angle) * min(1, 8 * Double(dt))
                b.angularVelocity = 0
            }

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
                         restAngle: b.restAngle, floor: b.floor, ceil: b.ceil,
                         minX: b.minX, maxX: b.maxX)
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

// MARK: - Advanced search models

enum RollSortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case mostShot
    case leastShot
    case nameAZ

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .newest:    return "Newest first"
        case .oldest:    return "Oldest first"
        case .mostShot:  return "Most shot"
        case .leastShot: return "Least shot"
        case .nameAZ:    return "Name A–Z"
        }
    }

    var icon: String {
        switch self {
        case .newest:    return "arrow.down"
        case .oldest:    return "arrow.up"
        case .mostShot:  return "chart.bar.fill"
        case .leastShot: return "chart.bar"
        case .nameAZ:    return "textformat.abc"
        }
    }
}

enum PushPullFilter: String, CaseIterable, Identifiable {
    case pushed
    case pulled
    case box

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .pushed: return "Pushed"
        case .pulled: return "Pulled"
        case .box:    return "Box speed"
        }
    }
}

// MARK: - Filter & Sort Sheet

struct RollFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sortOption: RollSortOption
    @Binding var filterFilm: String?
    @Binding var filterCamera: String?
    @Binding var filterLab: String?
    @Binding var filterYear: Int?
    @Binding var filterPushPull: PushPullFilter?

    let films: [String]
    let cameras: [String]
    let labs: [String]
    let years: [Int]
    let resultCount: Int

    private var hasActiveFilters: Bool {
        sortOption != .newest || filterFilm != nil || filterCamera != nil ||
        filterLab != nil || filterYear != nil || filterPushPull != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // SORT
                    section(title: "Sort") {
                        VStack(spacing: 8) {
                            ForEach(RollSortOption.allCases) { option in
                                Button {
                                    sortOption = option
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: option.icon)
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(width: 20)
                                            .foregroundColor(sortOption == option ? Color.filmAccent : Color.filmSecondary)
                                        Text(LocalizedStringKey(option.labelKey))
                                            .font(.system(size: 15, weight: sortOption == option ? .semibold : .regular))
                                            .foregroundColor(Color.filmText)
                                        Spacer()
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Color.filmAccent)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(sortOption == option ? Color.filmAccent.opacity(0.1) : Color.filmSurface)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !films.isEmpty {
                        section(title: "Film") {
                            chipFlow(films, selected: filterFilm) { value in
                                filterFilm = (filterFilm == value) ? nil : value
                            }
                        }
                    }

                    if !cameras.isEmpty {
                        section(title: "Camera") {
                            chipFlow(cameras, selected: filterCamera) { value in
                                filterCamera = (filterCamera == value) ? nil : value
                            }
                        }
                    }

                    if !labs.isEmpty {
                        section(title: "Lab") {
                            chipFlow(labs, selected: filterLab) { value in
                                filterLab = (filterLab == value) ? nil : value
                            }
                        }
                    }

                    if !years.isEmpty {
                        section(title: "Year") {
                            chipFlow(years.map { "\($0)" }, selected: filterYear.map { "\($0)" }) { value in
                                let intVal = Int(value)
                                filterYear = (filterYear == intVal) ? nil : intVal
                            }
                        }
                    }

                    section(title: "Push / Pull") {
                        HStack(spacing: 8) {
                            ForEach(PushPullFilter.allCases) { pp in
                                chip(
                                    label: NSLocalizedString(pp.labelKey, comment: ""),
                                    isSelected: filterPushPull == pp
                                ) {
                                    filterPushPull = (filterPushPull == pp) ? nil : pp
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle(Text("Filter & Sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        sortOption = .newest
                        filterFilm = nil
                        filterCamera = nil
                        filterLab = nil
                        filterYear = nil
                        filterPushPull = nil
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        Text("Reset")
                            .foregroundColor(hasActiveFilters ? Color.filmAccent : Color.filmTertiary)
                    }
                    .disabled(!hasActiveFilters)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done").fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text(L("Show %d rolls", resultCount))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(Color.filmAccent))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: .bold))
                .kerning(0.8)
                .foregroundColor(Color.filmTertiary)
            content()
        }
    }

    private func chipFlow(_ values: [String], selected: String?, onTap: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                chip(label: value, isSelected: selected == value) {
                    onTap(value)
                }
            }
        }
    }

    private func chip(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { onTap() }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.filmBackground : Color.filmSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.filmAccent : Color.filmSurface)
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : Color.filmBorder.opacity(0.5), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple flow layout for filter chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width - 40
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
