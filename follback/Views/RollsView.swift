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
                VStack(spacing: 24) {
                    headerSection

                    if rolls.isEmpty && !isLoading {
                        emptyState
                    } else if isLoading {
                        shimmerContent
                    } else {
                        rollList
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            showAddSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.filmText)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.filmSurface)
                                    .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddRollView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(for: Roll.self) { roll in
                RollDetailView(roll: roll)
                    .navigationBarBackButtonHidden(true)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isLoading = false
                        appeared = true
                    }
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FilmVault")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(Color.filmText)
                    Text("\(rolls.count) rolls · \(totalFrames) frames")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterPill(nil, label: "All", count: rolls.count)
                    filterPill(.inProgress, label: "Active", count: rolls.filter { $0.rollStatus == .inProgress }.count)
                    filterPill(.developed, label: "Developed", count: rolls.filter { $0.rollStatus == .developed }.count)
                    filterPill(.archived, label: "Archived", count: rolls.filter { $0.rollStatus == .archived }.count)
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -20)
    }

    private var totalFrames: Int {
        rolls.reduce(0) { $0 + ($1.frames?.count ?? 0) }
    }

    private func filterPill(_ status: RollStatus?, label: String, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if status == nil {
                    selectedFilter = nil
                } else {
                    selectedFilter = (selectedFilter == status) ? nil : status
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(selectedFilter == status ? Color.filmSurface : Color.filmAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(selectedFilter == status ? Color.filmBackground.opacity(0.25) : Color.filmAccent.opacity(0.12))
                        )
                }
            }
            .foregroundColor(selectedFilter == status ? Color.filmBackground : Color.filmText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedFilter == status ? Color.filmAccent : Color.filmSurface)
            )
            .overlay(
                Capsule()
                    .stroke(selectedFilter == status ? Color.clear : Color.filmBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var rollList: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(filteredRolls.enumerated()), id: \.element.id) { index, roll in
                NavigationLink(value: roll) {
                    RollCard(roll: roll, onDelete: { deleteRoll(roll) }, onArchive: { archiveRoll(roll) })
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .scaleEffect(appeared ? 1 : 0.96)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.75)
                    .delay(Double(index) * 0.07),
                    value: appeared
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.filmAccent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "camera.roll")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color.filmAccent)
            }

            VStack(spacing: 8) {
                Text("No rolls yet")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)
                Text("Start documenting your analog photography journey")
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                withAnimation(.spring(response: 0.35)) {
                    showAddSheet = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Roll")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.filmBackground)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.filmAccent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
    }

    private var shimmerContent: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.filmSurface)
                    .frame(height: 140)
                    .shimmering(
                        gradient: Gradient(colors: [.clear, Color.filmAccent.opacity(0.06), .clear]),
                        bandSize: 0.5
                    )
            }
        }
        .padding(.horizontal, 16)
    }

    private func deleteRoll(_ roll: Roll) {
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(roll)
            try? modelContext.save()
        }
    }

    private func archiveRoll(_ roll: Roll) {
        withAnimation(.easeInOut(duration: 0.25)) {
            roll.updateStatus(.archived)
            try? modelContext.save()
        }
    }
}
