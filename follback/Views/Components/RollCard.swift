import SwiftUI
import SwiftData

struct RollCard: View {
    let roll: Roll
    let onDelete: () -> Void
    let onArchive: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar with status color
            statusBar
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(roll.filmName)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundColor(Color.filmText)
                            .lineLimit(1)

                        Text(roll.camera?.name ?? "No camera")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.filmSecondary)
                    }

                    Spacer()

                    statusBadge
                }

                // Film specs
                HStack(spacing: 8) {
                    specBadge("ISO \(roll.iso)")
                    specBadge("\(roll.capacity) frames")
                    specBadge(roll.filmFormat.displayName)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.filmSprocket)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(gradientFill)
                                .frame(width: geo.size.width * CGFloat(roll.filledFrames) / CGFloat(max(roll.capacity, 1)), height: 6)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: roll.filledFrames)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(roll.filledFrames) of \(roll.capacity)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.filmTertiary)
                        Spacer()
                        if roll.pushPull != 0 {
                            Text(String(format: "%+.1f stops", roll.pushPull))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.filmGold)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    private var statusBar: some View {
        statusColor
    }

    private var statusBadge: some View {
        Text(roll.rollStatus.displayName)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.25), lineWidth: 0.5)
            )
    }

    private var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .developed: return Color.filmSuccess
        case .archived: return Color.filmTertiary
        }
    }

    private var gradientFill: LinearGradient {
        LinearGradient(
            colors: [Color.filmAccent, Color.filmGold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func specBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.filmSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.filmSurfaceSecondary)
            )
    }
}
