import SwiftUI
import Kingfisher

extension RollDetailView {

    var formattedShootingDate: String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.setLocalizedDateFormatFromTemplate("ddMMyyyy")
        return formatter.string(from: roll.startDate)
    }

    // MARK: - Hero Section (Filmer style)
    var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Roll title
            Text(roll.filmName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.filmText)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Film cover + info chips (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Film cover image (long-press to change film)
                    filmCoverImage
                        .contextMenu {
                            Button {
                                showFilmPicker = true
                            } label: {
                                Label("Change Film Stock", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }

                    Button {
                        showFormatPicker = true
                    } label: {
                        infoChipView(
                            label: "Film format",
                            value: roll.filmFormat.isSheet
                                ? "\(roll.filmFormat.displayName) · \(L("Sheet"))"
                                : roll.isHalfFrame
                                    ? "\(roll.filmFormat.displayName) · \(L("Half"))"
                                    : roll.filmFormat.displayName
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    infoChipView(label: "ISO", value: "\(roll.iso)")

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    // Date shooting next to ISO
                    Button {
                        editingDate = roll.startDate
                        showDatePicker = true
                    } label: {
                        infoChipView(label: "Date", value: formattedShootingDate)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    infoChipView(label: "Photos", value: "\(roll.filledFrames)/\(roll.capacity)")

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)
                    Button {
                        showCameraPicker = true
                    } label: {
                        infoChipView(label: "Camera", value: roll.camera?.name ?? L("Add"))
                    }
                    .buttonStyle(.plain)

                    if roll.pushPull != 0 {
                        Divider()
                            .frame(height: 40)
                            .background(Color.filmBorder)
                        infoChipView(label: "Push/Pull", value: String(format: "%+.1f", roll.pushPull))
                    }
                }
                .padding(.horizontal, 16)
            }

            if let location = roll.locationName {
                Button {
                    showLocationEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(location)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .foregroundColor(Color.filmTertiary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            if let lab = roll.labName {
                Button {
                    showLabPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 12))
                        Text(lab)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .foregroundColor(Color.filmTertiary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            if !roll.notes.isEmpty {
                Text(roll.notes)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.filmSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            developmentCard
                .padding(.horizontal, 16)

            costCard
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    var costCard: some View {
        Button {
            showEditDetails = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmAccent)
                    Text("COST")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)
                    Spacer()
                    Image(systemName: roll.hasCost ? "pencil" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.filmTertiary)
                }

                if roll.hasCost {
                    VStack(alignment: .leading, spacing: 6) {
                        if let film = roll.filmCost {
                            costLine(label: L("Film cost"), value: Money.format(film))
                        }
                        if let dev = roll.devCost {
                            costLine(label: L("Developing cost"), value: Money.format(dev))
                        }
                        if let total = roll.totalCost {
                            Divider().background(Color.filmBorder.opacity(0.3))
                            costLine(label: L("Total cost"), value: Money.format(total), emphasized: true)
                        }
                    }
                } else {
                    Text("Track what you spent on film and developing.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .buttonStyle(.plain)
    }

    func costLine(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: emphasized ? .semibold : .regular))
                .foregroundColor(emphasized ? Color.filmText : Color.filmSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: emphasized ? .bold : .medium))
                .foregroundColor(emphasized ? Color.filmAccent : Color.filmText)
        }
    }

    var developmentCard: some View {
        Button {
            showDevRecipe = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmAccent)
                    Text("DEVELOPMENT")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)
                    Spacer()
                    Image(systemName: roll.hasDevRecipe ? "pencil" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.filmTertiary)
                }

                if roll.hasDevRecipe {
                    VStack(alignment: .leading, spacing: 6) {
                        if let dev = roll.devDeveloper, !dev.isEmpty {
                            devLine(icon: "flask.fill",
                                    text: [dev, roll.devDilution].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  "))
                        }
                        if !devTempTimeText.isEmpty {
                            devLine(icon: "thermometer.medium", text: devTempTimeText)
                        }
                        if roll.pushPull != 0 {
                            devLine(icon: "arrow.up.arrow.down",
                                    text: "\(roll.pushPull > 0 ? L("Push") : L("Pull")) \(String(format: "%+d", Int(roll.pushPull))) \(abs(roll.pushPull) == 1 ? L("stop") : L("stops"))")
                        }
                        if let agit = roll.devAgitation, !agit.isEmpty {
                            devLine(icon: "hand.draw", text: agit)
                        }
                        if let date = roll.developedDate {
                            devLine(icon: "calendar", text: L("Developed %@", date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(appLocale()))))
                        }
                        if let notes = roll.devNotes, !notes.isEmpty {
                            devLine(icon: "text.alignleft", text: notes)
                        }
                    }
                } else {
                    Text("Log your developer, dilution, temperature, time and push/pull.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .buttonStyle(.plain)
    }

    var devTempTimeText: String {
        var parts: [String] = []
        if let t = roll.devTempC { parts.append(String(format: "%.1f °C", t)) }
        if let s = roll.devTimeSeconds { parts.append(DevRecipePresets.timeLabel(s)) }
        return parts.joined(separator: "  ·  ")
    }

    func devLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.filmAccent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var filmCoverImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.filmSurface)
                .frame(width: 72, height: 72)

            if let custom = matchingCustomFilm,
               let data = custom.coverImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let stock = matchingFilmStock,
               let coverUrlString = stock.githubCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .downsampling(size: CGSize(width: 144, height: 144))
                    .cacheOriginalImage()
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }
        }
        .onTapGesture {
            if let stock = matchingFilmStock {
                filmDetailStock = stock
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showFilmPicker = true
        }
    }

    func infoChipView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.filmTertiary)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.filmText)
        }
    }
}
