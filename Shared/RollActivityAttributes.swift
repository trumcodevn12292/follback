import Foundation
import ActivityKit

/// Attributes describing the film roll currently being tracked on the Lock
/// Screen / Dynamic Island.
///
/// This file is shared between the app target (which starts/updates/ends the
/// Live Activity) and the widget extension target (which renders it), so it
/// lives in the `Shared/` synchronized folder that belongs to both targets.
struct FilmVaultRollAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Number of frames already shot (frames that have a photo attached).
        var shotFrames: Int
        /// Localization key describing the roll state: "Shooting" / "Shot" / "Developed".
        var statusKey: String
        /// When the underlying roll last changed (used for relative-time display).
        var updatedAt: Date

        public init(shotFrames: Int, statusKey: String, updatedAt: Date) {
            self.shotFrames = shotFrames
            self.statusKey = statusKey
            self.updatedAt = updatedAt
        }
    }

    /// Stable identity of the roll (UUID string) so deep links can open it.
    var rollID: String
    var filmName: String
    var cameraName: String?
    /// Pre-formatted ISO label, e.g. "ISO 400".
    var isoText: String
    /// Total number of frames the roll holds.
    var capacity: Int
    /// Pre-formatted film format, e.g. "35mm".
    var formatText: String
    /// Pre-formatted push/pull label, e.g. "+1", or nil when box speed.
    var pushPullText: String?

    public init(rollID: String,
                filmName: String,
                cameraName: String?,
                isoText: String,
                capacity: Int,
                formatText: String,
                pushPullText: String?) {
        self.rollID = rollID
        self.filmName = filmName
        self.cameraName = cameraName
        self.isoText = isoText
        self.capacity = capacity
        self.formatText = formatText
        self.pushPullText = pushPullText
    }
}
