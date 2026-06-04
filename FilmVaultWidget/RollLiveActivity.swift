import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

// MARK: - Live Activity (Lock Screen + Dynamic Island)

/// Live Activity that shows the roll you are currently shooting on the Lock
/// Screen and in the Dynamic Island. All labels are localized via `WL(...)`
/// using the language the user picked inside the app (shared through the App
/// Group), and the layout flips to RTL when Arabic is selected.
struct RollLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FilmVaultRollAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .environment(\.layoutDirection, widgetLayoutDirection())
                .widgetURL(URL(string: "filmvault://roll/\(context.attributes.rollID)"))
        } dynamicIsland: { context in
            dynamicIsland(context: context)
        }
    }

    private func dynamicIsland(context: ActivityViewContext<FilmVaultRollAttributes>) -> DynamicIsland {
        let shot = context.state.shotFrames
        let cap = context.attributes.capacity
        let progress = cap > 0 ? min(1.0, Double(shot) / Double(cap)) : 0

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                HStack(alignment: .center, spacing: 8) {
                    liveActivityFilmIcon(context.attributes.filmName, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.attributes.filmName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        if let cam = context.attributes.cameraName, !cam.isEmpty {
                            Text(cam)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.leading, 4)
            }
            DynamicIslandExpandedRegion(.trailing) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(shot)/\(cap)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(WL(context.state.statusKey))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.trailing, 4)
            }
            DynamicIslandExpandedRegion(.bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(.orange)
                    HStack {
                        Text(context.attributes.isoText)
                        if let pp = context.attributes.pushPullText, !pp.isEmpty {
                            Text("•")
                            Text(pp)
                        }
                        Spacer()
                        Text(WL("%d left", max(0, cap - shot)))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .environment(\.layoutDirection, widgetLayoutDirection())
            }
        } compactLeading: {
            liveActivityFilmIcon(context.attributes.filmName, size: 20)
        } compactTrailing: {
            Text("\(shot)/\(cap)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        } minimal: {
            Text("\(shot)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.orange)
        }
        .widgetURL(URL(string: "filmvault://roll/\(context.attributes.rollID)"))
        .keylineTint(.orange)
    }
}

// MARK: - Lock Screen view

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FilmVaultRollAttributes>

    private var shot: Int { context.state.shotFrames }
    private var cap: Int { context.attributes.capacity }
    private var progress: Double {
        cap > 0 ? min(1.0, Double(shot) / Double(cap)) : 0
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let cover = liveActivityCoverImage(for: context.attributes.filmName) {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                }
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if liveActivityCoverImage(for: context.attributes.filmName) == nil {
                    Image(systemName: "film")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(WL("Now Shooting"))
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(.orange)
                Text(context.attributes.filmName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(context.attributes.isoText)
                    if let cam = context.attributes.cameraName, !cam.isEmpty {
                        Text("•")
                        Text(cam).lineLimit(1)
                    }
                    if let pp = context.attributes.pushPullText, !pp.isEmpty {
                        Text("•")
                        Text(pp)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(shot)/\(cap)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(WL("%d left", max(0, cap - shot)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.55))
        .activitySystemActionForegroundColor(.orange)
    }
}

private func widgetLayoutDirection() -> LayoutDirection {
    widgetLanguageCode() == "ar" ? .rightToLeft : .leftToRight
}

// MARK: - Film cover helpers

/// Loads the cached film cover image (written by the app into the shared App
/// Group container under `WidgetCovers/`) for the given film name. Returns nil
/// when no cover has been cached for that film.
func liveActivityCoverImage(for filmName: String) -> UIImage? {
    let safeName = filmName
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "/", with: "_")
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.williamcachamwri.FilmVault"
    ) else { return nil }
    let fileURL = containerURL
        .appendingPathComponent("WidgetCovers")
        .appendingPathComponent("cover_\(safeName).jpg")
    guard let data = try? Data(contentsOf: fileURL),
          let image = UIImage(data: data) else { return nil }
    // Live Activities / Dynamic Island have a much tighter rendering budget than
    // home-screen widgets, so a full-resolution cover renders blank. Downscale
    // to a small thumbnail so it always displays.
    return image.downscaled(toMaxDimension: 120)
}

private extension UIImage {
    func downscaled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

/// Shows the film cover thumbnail when available, falling back to the orange
/// filmstrip SF Symbol when no cover has been cached.
@ViewBuilder
func liveActivityFilmIcon(_ filmName: String, size: CGFloat) -> some View {
    if let cover = liveActivityCoverImage(for: filmName) {
        Image(uiImage: cover)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    } else {
        Image(systemName: "film")
            .font(.system(size: size * 0.72))
            .foregroundStyle(.orange)
    }
}
