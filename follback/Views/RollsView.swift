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
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var editingRoll: Roll?
    @State private var filmDetailStock: FilmStock?

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
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("FILMVAULT")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(Color.filmText)
                .kerning(1.5)

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
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
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
