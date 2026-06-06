import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

// MARK: - Live Activity (Lock Screen + Dynamic Island)

struct RollLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FilmVaultRollAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .environment(\.layoutDirection, widgetLayoutDirection())
                .widgetURL(URL(string: "filmvault://roll/\(context.attributes.rollID)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context)
                }
            } compactLeading: {
                compactLeading(context)
            } compactTrailing: {
                compactTrailing(context)
            } minimal: {
                minimal(context)
            }
            .widgetURL(URL(string: "filmvault://roll/\(context.attributes.rollID)"))
            .keylineTint(.orange)
        }
    }

    // MARK: - Dynamic Island Expanded

    private func expandedLeading(_ context: ActivityViewContext<FilmVaultRollAttributes>) -> some View {
        HStack(spacing: 8) {
            filmThumbnail(filmName: context.attributes.filmName, size: 30, cornerRadius: 7)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                    Text(context.attributes.filmName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                if let cam = context.attributes.cameraName, !cam.isEmpty {
                    Text(cam)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(.leading, 2)
    }

    private func expandedTrailing(_ context: ActivityViewContext<FilmVaultRollAttributes>) -> some View {
        let shot = context.state.shotFrames
        let cap = context.attributes.capacity
        return VStack(alignment: .trailing, spacing: 1) {
            Text("\(shot)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("/\(cap)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.trailing, 4)
    }

    private func expandedBottom(_ context: ActivityViewContext<FilmVaultRollAttributes>) -> some View {
        let shot = context.state.shotFrames
        let cap = context.attributes.capacity
        let progress = cap > 0 ? min(1.0, Double(shot) / Double(cap)) : 0
        let remaining = max(0, cap - shot)

        return VStack(spacing: 8) {
            ProgressView(value: progress)
                .tint(.orange)

            HStack(spacing: 0) {
                if remaining > 0 {
                    HStack(spacing: 4) {
                        Text("\(remaining)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(WL("left"))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Label(WL("Full"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                }

                Spacer()

                Text(WL(context.state.statusKey))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .environment(\.layoutDirection, widgetLayoutDirection())
    }

    // MARK: - Dynamic Island Compact & Minimal

    private func compactLeading(_ context: ActivityViewContext<FilmVaultRollAttributes>) -> some View {
        filmThumbnail(filmName: context.attributes.filmName, size: 22, cornerRadius: 5)
    }

    private func compactTrailing(_ context: ActivityViewContext<FilmVaultRollAttributes>) -> some View {
        let shot = context.state.shotFrames
        let cap = context.attributes.capacity
        return HStack(spacing: 2) {
            Text("\(shot)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("/\(cap)")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    private func minimal(_ context: ActivityViewContext<FilmVaultRollAttributes>) -> some View {
        let shot = context.state.shotFrames
        let cap = context.attributes.capacity
        let progress = cap > 0 ? min(1.0, Double(shot) / Double(cap)) : 0
        return ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(shot)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.orange)
        }
        .padding(2)
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FilmVaultRollAttributes>

    private var shot: Int { context.state.shotFrames }
    private var cap: Int { context.attributes.capacity }
    private var progress: Double {
        cap > 0 ? min(1.0, Double(shot) / Double(cap)) : 0
    }
    private var remaining: Int { max(0, cap - shot) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                filmThumbnail(filmName: context.attributes.filmName, size: 46, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 5, height: 5)
                        Text(WL("Now Shooting"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }

                    Text(context.attributes.filmName)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(context.attributes.isoText)
                            .font(.system(size: 11, weight: .medium))
                        if let cam = context.attributes.cameraName, !cam.isEmpty {
                            Text("\u{00B7}")
                                .foregroundStyle(.tertiary)
                            Text(cam)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        if let pp = context.attributes.pushPullText, !pp.isEmpty {
                            Text("\u{00B7}")
                                .foregroundStyle(.tertiary)
                            Text(pp)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(shot)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/\(cap)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                ProgressView(value: progress)
                    .tint(.orange)

                if remaining > 0 {
                    Text("\(remaining)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(WL("left"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text(WL("Full"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .activityBackgroundTint(Color.primary.opacity(0.12))
        .activitySystemActionForegroundColor(.orange)
    }
}

// MARK: - Shared Thumbnail Builder

@ViewBuilder
private func filmThumbnail(filmName: String, size: CGFloat, cornerRadius: CGFloat) -> some View {
    if let cover = liveActivityCoverImage(for: filmName) {
        Image(uiImage: cover)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
    } else {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.orange.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.orange)
            )
    }
}

// MARK: - Layout Direction

private func widgetLayoutDirection() -> LayoutDirection {
    widgetLanguageCode() == "ar" ? .rightToLeft : .leftToRight
}

// MARK: - Film Cover Helpers

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
