import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]

    @State private var searchText = ""
    @State private var appeared = false
    @FocusState private var isSearchFocused: Bool

    private var rollResults: [Roll] {
        guard !searchText.isEmpty else { return [] }
        let lower = searchText.lowercased()
        return rolls.filter {
            $0.filmName.lowercased().contains(lower) ||
            $0.camera?.name.lowercased().contains(lower) == true ||
            $0.notes.lowercased().contains(lower)
        }
    }

    private var frameResults: [Frame] {
        guard !searchText.isEmpty else { return [] }
        let lower = searchText.lowercased()
        var results: [Frame] = []
        for roll in rolls {
            guard let frames = roll.frames else { continue }
            for frame in frames {
                if frame.notes.lowercased().contains(lower) ||
                   frame.locationName?.lowercased().contains(lower) == true {
                    results.append(frame)
                }
            }
        }
        return results
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection

                    searchField

                    resultsSection
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Roll.self) { roll in
                RollDetailView(roll: roll)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Find")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
            Text("Search through your rolls and frames")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -20)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.filmTertiary)

            TextField("Search rolls, frames, notes...", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.filmTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSearchFocused ? Color.filmAccent.opacity(0.5) : Color.filmBorder, lineWidth: isSearchFocused ? 1.5 : 0.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !searchText.isEmpty {
            VStack(spacing: 20) {
                if !rollResults.isEmpty {
                    resultGroup(title: "Rolls", icon: "camera.roll") {
                        ForEach(rollResults) { roll in
                            NavigationLink(value: roll) {
                                rollResultRow(roll: roll)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !frameResults.isEmpty {
                    resultGroup(title: "Frames", icon: "photo") {
                        ForEach(frameResults) { frame in
                            if let roll = frame.roll {
                                NavigationLink(value: roll) {
                                    frameResultRow(frame: frame, roll: roll)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if rollResults.isEmpty && frameResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(Color.filmTertiary)
                        Text("No results found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmSecondary)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private func resultGroup<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmAccent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            VStack(spacing: 8) {
                content()
            }
        }
    }

    private func rollResultRow(roll: Roll) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.filmAccent.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "camera.roll")
                    .font(.system(size: 20))
                    .foregroundColor(Color.filmAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(roll.filmName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.filmText)
                Text("\(roll.camera?.name ?? "No camera") · \(roll.filmFormat.displayName)")
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
    }

    private func frameResultRow(frame: Frame, roll: Roll) -> some View {
        HStack(spacing: 12) {
            if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.filmSprocket)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text("\(frame.number)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Frame #\(frame.number) · \(roll.filmName)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmText)
                if let ap = frame.apertureDisplay, let sh = frame.shutterDisplay {
                    Text("\(ap)  \(sh)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.filmSecondary)
                }
                if let loc = frame.locationName {
                    Text(loc)
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
    }
}
