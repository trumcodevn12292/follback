import SwiftUI
import SwiftData
import Shimmer

struct RollsView: View {
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddSheet = false
    @State private var selectedFilter: RollStatus? = nil
    @State private var appeared = false
    @State private var isLoading = true

    private var filteredRolls: [Roll] {
        guard let filter = selectedFilter else { return rolls }
        return rolls.filter { $0.rollStatus == filter }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
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
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.filmAccent.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .fullScreenCover(isPresented: $showAddSheet) {
                NavigationStack {
                    AddRollView()
                }
            }
            .navigationDestination(for: Roll.self) { roll in
                RollDetailView(roll: roll)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        isLoading = false
                        appeared = true
                    }
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FilmVault")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)

            Text("\(rolls.count) rolls · \(totalFrames) frames")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(.easeOut(duration: 0.3), value: appeared)
    }

    private var totalFrames: Int {
        rolls.reduce(0) { $0 + ($1.frames?.count ?? 0) }
    }

    // MARK: - Filters

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(nil, label: "All", count: rolls.count)
                filterPill(.inProgress, label: "Active", count: rolls.filter { $0.rollStatus == .inProgress }.count)
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
            withAnimation(.easeInOut(duration: 0.2)) {
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
                    RollCard(roll: roll, onDelete: { deleteRoll(roll) }, onArchive: { archiveRoll(roll) })
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(
                    .easeOut(duration: 0.35).delay(Double(index) * 0.04),
                    value: appeared
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
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

            Button {
                showAddSheet = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("Create Roll")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmBackground)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.filmAccent)
                    )
            }
            .buttonStyle(.plain)
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
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(roll)
            try? modelContext.save()
        }
    }

    private func archiveRoll(_ roll: Roll) {
        withAnimation(.easeInOut(duration: 0.2)) {
            roll.updateStatus(.archived)
            try? modelContext.save()
        }
    }
}
