import AppIntents
import Foundation
import WidgetKit

// MARK: - Intent localization

/// Localizes runtime dialog strings using the language the user picked inside
/// the app (shared via UserDefaults), so spoken / shown results match the app
/// even when the intent runs outside the app process.
private func IL(_ key: String) -> String {
    let code = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return NSLocalizedString(key, comment: "")
}

private func IL(_ key: String, _ args: CVarArg...) -> String {
    String(format: IL(key), arguments: args)
}

/// Build a dialog from an already-localized runtime string. The string is used
/// as a (non-existent) key, so `LocalizedStringResource` falls back to the
/// string itself verbatim.
private func dialog(_ text: String) -> IntentDialog {
    IntentDialog(stringLiteral: text)
}

// MARK: - Shared snapshot access

enum FilmVaultIntentData {
    static let appGroup = "group.com.williamcachamwri.FilmVault"

    static func snapshot() -> IntentSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: "intentData"),
              let snapshot = try? JSONDecoder().decode(IntentSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    static func activeRoll() -> IntentRollItem? {
        guard let snap = snapshot() else { return nil }
        if let id = snap.activeRollID {
            return snap.allRolls.first { $0.id == id }
        }
        return snap.allRolls.first { $0.status == "In Progress" }
    }

    static func roll(id: String) -> IntentRollItem? {
        snapshot()?.allRolls.first { $0.id == id }
    }

    /// Queue an action for the app to perform when it next becomes active.
    static func queue(action: String?, rollID: String?) {
        let defaults = UserDefaults(suiteName: appGroup)
        defaults?.set(action, forKey: "pendingIntentAction")
        defaults?.set(rollID, forKey: "pendingIntentRollID")
    }
}

// MARK: - Roll entity (lets users pick a specific roll in Shortcuts)

struct RollEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Roll")
    }

    static var defaultQuery = RollEntityQuery()

    var id: String
    var filmName: String
    var photoCount: Int
    var capacity: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(filmName)",
            subtitle: "\(photoCount)/\(capacity)"
        )
    }

    init(item: IntentRollItem) {
        self.id = item.id
        self.filmName = item.filmName
        self.photoCount = item.photoCount
        self.capacity = item.capacity
    }
}

struct RollEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RollEntity] {
        let all = FilmVaultIntentData.snapshot()?.allRolls ?? []
        return all.filter { identifiers.contains($0.id) }.map(RollEntity.init)
    }

    func suggestedEntities() async throws -> [RollEntity] {
        (FilmVaultIntentData.snapshot()?.allRolls ?? []).map(RollEntity.init)
    }
}

// MARK: - Current roll status

struct CurrentRollStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Current Roll Status"
    static var description = IntentDescription("Check how many frames you've shot on the roll you're currently shooting.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let roll = FilmVaultIntentData.activeRoll() else {
            return .result(dialog: dialog(IL("No roll in progress right now.")))
        }
        let left = max(0, roll.capacity - roll.photoCount)
        let text = IL("You've shot %d of %d frames on %@, %d left.",
                      roll.photoCount, roll.capacity, roll.filmName, left)
        return .result(dialog: dialog(text))
    }
}

// MARK: - Frames left (optionally for a chosen roll)

struct FramesLeftIntent: AppIntent {
    static var title: LocalizedStringResource = "Frames Left"
    static var description = IntentDescription("Ask how many frames are left on a film roll.")
    static var openAppWhenRun = false

    @Parameter(title: "Roll")
    var roll: RollEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("How many frames left on \(\.$roll)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let item: IntentRollItem?
        if let chosen = roll {
            item = FilmVaultIntentData.roll(id: chosen.id)
        } else {
            item = FilmVaultIntentData.activeRoll()
        }
        guard let roll = item else {
            return .result(dialog: dialog(IL("No roll in progress right now.")))
        }
        let left = max(0, roll.capacity - roll.photoCount)
        let text = IL("%d frames left on %@.", left, roll.filmName)
        return .result(dialog: dialog(text))
    }
}

// MARK: - Open the current roll

struct OpenCurrentRollIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Current Roll"
    static var description = IntentDescription("Open the roll you're currently shooting in FilmVault.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let roll = FilmVaultIntentData.activeRoll() else {
            return .result(dialog: dialog(IL("No roll in progress right now.")))
        }
        FilmVaultIntentData.queue(action: "openRoll", rollID: roll.id)
        return .result(dialog: dialog(IL("Opening %@.", roll.filmName)))
    }
}

// MARK: - Start / stop Lock Screen tracking

struct StartRollTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Roll on Lock Screen"
    static var description = IntentDescription("Show the roll you're currently shooting as a Live Activity on the Lock Screen.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: LiveActivityManager.enabledKey)
        FilmVaultIntentData.queue(action: "startTracking", rollID: nil)
        guard let roll = FilmVaultIntentData.activeRoll() else {
            return .result(dialog: dialog(IL("No roll in progress right now.")))
        }
        return .result(dialog: dialog(IL("Tracking %@ on your Lock Screen.", roll.filmName)))
    }
}

struct StopRollTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Lock Screen Tracking"
    static var description = IntentDescription("Remove the current roll Live Activity from the Lock Screen.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(false, forKey: LiveActivityManager.enabledKey)
        LiveActivityManager.shared.endAll()
        return .result(dialog: dialog(IL("Stopped Lock Screen tracking.")))
    }
}

// MARK: - New roll

struct NewRollIntent: AppIntent {
    static var title: LocalizedStringResource = "New Film Roll"
    static var description = IntentDescription("Start logging a new film roll in FilmVault.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        FilmVaultIntentData.queue(action: "newRoll", rollID: nil)
        return .result()
    }
}

// MARK: - App Shortcuts (Siri phrases)

struct FilmVaultShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CurrentRollStatusIntent(),
            phrases: [
                "Check my roll in \(.applicationName)",
                "What's my \(.applicationName) roll status",
                "How is my film roll in \(.applicationName)"
            ],
            shortTitle: "Current Roll Status",
            systemImageName: "film"
        )
        AppShortcut(
            intent: FramesLeftIntent(),
            phrases: [
                "How many frames left in \(.applicationName)",
                "Frames left in \(.applicationName)"
            ],
            shortTitle: "Frames Left",
            systemImageName: "number"
        )
        AppShortcut(
            intent: OpenCurrentRollIntent(),
            phrases: [
                "Open my roll in \(.applicationName)",
                "Open current roll in \(.applicationName)"
            ],
            shortTitle: "Open Current Roll",
            systemImageName: "arrow.up.forward.app"
        )
        AppShortcut(
            intent: StartRollTrackingIntent(),
            phrases: [
                "Track my roll in \(.applicationName)",
                "Show my roll on the Lock Screen with \(.applicationName)"
            ],
            shortTitle: "Show Roll on Lock Screen",
            systemImageName: "lock.iphone"
        )
        AppShortcut(
            intent: NewRollIntent(),
            phrases: [
                "Start a new roll in \(.applicationName)",
                "New film roll in \(.applicationName)"
            ],
            shortTitle: "New Film Roll",
            systemImageName: "plus.circle"
        )
    }
}
