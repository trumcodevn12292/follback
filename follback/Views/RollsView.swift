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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.filmAccent, Color.filmGold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.filmSurface)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.filmBorder, lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("FilmVault")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.filmText, Color.filmText.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "film")
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmAccent)
                        Text("\(rolls.count) rolls")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.filmSecondary)
                        Text("·")
                            .foregroundColor(Color.filmTertiary)
                        Text("\(totalFrames) frames")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.filmSecondary)
                    }
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
        let isActive = selectedFilter == status
        return Button {
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
                        .foregroundColor(isActive ? Color.filmBackground : Color.filmAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isActive ? Color.filmBackground.opacity(0.25) : Color.filmAccent.opacity(0.12))
                        )
                }
            }
            .foregroundColor(isActive ? Color.filmBackground : Color.filmText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        isActive
                        ? AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.filmSurface)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : Color.filmBorder, lineWidth: 0.5)
            )
            .shadow(color: isActive ? Color.filmAccent.opacity(0.25) : Color.clear, radius: 8, x: 0, y: 3)
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
                    .delay(Double(index) * 0.06),
                    value: appeared
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.filmAccent.opacity(0.1), Color.filmAccent.opacity(0.02)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .stroke(Color.filmAccent.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Image(systemName: "film")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("No rolls yet")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)
                Text("Start documenting your analog\nphotography journey")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                withAnimation(.spring(response: 0.35)) {
                    showAddSheet = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New Roll")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.filmBackground)
                .padding(.horizontal, 32)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.filmAccent, Color.filmGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.filmAccent.opacity(0.35), radius: 12, x: 0, y: 5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
    }

    private var shimmerContent: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.filmSurface)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
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
