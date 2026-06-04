import Foundation
import ActivityKit

/// Drives the Lock Screen / Dynamic Island Live Activity for the roll the user
/// is currently shooting. The app is the single source of truth (SwiftData), so
/// it starts / updates / ends the activity whenever roll data changes.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    /// Whether the user wants the current roll shown on the Lock Screen.
    /// Defaults to ON when the user has never toggled it.
    static let enabledKey = "liveActivityEnabled"

    var isFeatureEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func setFeatureEnabled(_ enabled: Bool, rolls: [Roll]) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        sync(rolls: rolls)
    }

    /// The roll considered "currently shooting": the most recently updated
    /// in-progress roll.
    static func activeRoll(from rolls: [Roll]) -> Roll? {
        rolls
            .filter { $0.rollStatus == .inProgress }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    /// Reconcile the running Live Activity with the current data.
    func sync(rolls: [Roll]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard isFeatureEnabled, let roll = Self.activeRoll(from: rolls) else {
            endAll()
            return
        }

        let attributes = attributes(for: roll)
        let state = contentState(for: roll)
        let content = ActivityContent(state: state, staleDate: nil)

        let running = Activity<FilmVaultRollAttributes>.activities

        if let existing = running.first(where: { $0.attributes.rollID == roll.id.uuidString }) {
            // End any stray activities for other rolls, then update this one.
            for other in running where other.id != existing.id {
                Task { await other.end(nil, dismissalPolicy: .immediate) }
            }
            Task { await existing.update(content) }
        } else {
            // A different roll (or none) is showing -> clear and start fresh.
            for other in running {
                Task { await other.end(nil, dismissalPolicy: .immediate) }
            }
            do {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } catch {
                // Starting can fail when the app is not foregrounded; it will be
                // retried on the next sync once the app is active.
            }
        }
    }

    func endAll() {
        for activity in Activity<FilmVaultRollAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Mapping

    private func attributes(for roll: Roll) -> FilmVaultRollAttributes {
        FilmVaultRollAttributes(
            rollID: roll.id.uuidString,
            filmName: roll.filmName,
            cameraName: Self.cameraName(roll.camera),
            isoText: "ISO \(roll.iso)",
            capacity: roll.capacity,
            formatText: roll.filmFormat.displayName,
            pushPullText: Self.pushPullText(roll.pushPull)
        )
    }

    private func contentState(for roll: Roll) -> FilmVaultRollAttributes.ContentState {
        FilmVaultRollAttributes.ContentState(
            shotFrames: roll.filledFrames,
            statusKey: roll.rollStatus.displayName,
            updatedAt: roll.updatedAt
        )
    }

    static func cameraName(_ camera: Camera?) -> String? {
        guard let camera else { return nil }
        let combined = "\(camera.brand) \(camera.name)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? nil : combined
    }

    static func pushPullText(_ value: Float) -> String? {
        guard value != 0 else { return nil }
        let rounded = (value * 10).rounded() / 10
        let number: String
        if rounded == rounded.rounded() {
            number = String(Int(rounded))
        } else {
            number = String(format: "%.1f", rounded)
        }
        return rounded > 0 ? "+\(number)" : number
    }
}
