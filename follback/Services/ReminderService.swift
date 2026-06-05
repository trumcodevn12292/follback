import Foundation
import Combine
import UserNotifications
import UIKit

// MARK: - Reminder Settings keys (shared with SettingsView via AppStorage)

enum ReminderDefaults {
    static let enabledKey = "remindersEnabled"
    static let staleDaysKey = "reminderStaleDays"
    static let developDaysKey = "reminderDevelopDays"
    static let hourKey = "reminderHour"

    static let defaultStaleDays = 21
    static let defaultDevelopDays = 3
    static let defaultHour = 10

    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var staleDays: Int {
        let v = UserDefaults.standard.integer(forKey: staleDaysKey)
        return v == 0 ? defaultStaleDays : v
    }
    static var developDays: Int {
        let v = UserDefaults.standard.integer(forKey: developDaysKey)
        return v == 0 ? defaultDevelopDays : v
    }
    static var hour: Int {
        let v = UserDefaults.standard.object(forKey: hourKey) as? Int
        return v ?? defaultHour
    }
}

@MainActor
final class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "reminder."

    private init() {}

    // MARK: Authorization

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Requests permission. Returns whether it is now authorized.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            refreshAuthorizationStatus()
            return granted
        } catch {
            refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: Scheduling

    func reschedule(rolls: [Roll]) {
        // Always clear our own pending requests first.
        center.getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            guard ReminderDefaults.enabled else { return }
            self.center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                Task { @MainActor in
                    self.buildAndAddRequests(rolls: rolls)
                }
            }
        }
    }

    private func buildAndAddRequests(rolls: [Roll]) {
        let staleDays = ReminderDefaults.staleDays
        let developDays = ReminderDefaults.developDays
        let hour = ReminderDefaults.hour
        let now = Date()
        let calendar = Calendar.current

        for roll in rolls {
            switch roll.rollStatus {
            case .inProgress:
                let base = calendar.date(byAdding: .day, value: staleDays, to: roll.startDate) ?? roll.startDate
                let fireDate = normalizedFireDate(from: base, hour: hour, now: now, calendar: calendar)
                addRequest(
                    id: "\(idPrefix)stale.\(roll.id.uuidString)",
                    title: L("Still shooting %@?", roll.filmName),
                    body: L("This roll has been in progress for a while. %d/%d frames so far.", roll.filledFrames, roll.capacity),
                    fireDate: fireDate,
                    calendar: calendar
                )
            case .completed:
                let base = calendar.date(byAdding: .day, value: developDays, to: roll.updatedAt) ?? roll.updatedAt
                let fireDate = normalizedFireDate(from: base, hour: hour, now: now, calendar: calendar)
                addRequest(
                    id: "\(idPrefix)develop.\(roll.id.uuidString)",
                    title: L("Time to develop %@", roll.filmName),
                    body: L("You finished this roll. Drop it off at the lab so you don't forget."),
                    fireDate: fireDate,
                    calendar: calendar
                )
            case .developed, .archived:
                break
            }
        }

        scheduleInactivityReminder(rolls: rolls)
        checkRollAchievements(rolls: rolls)
    }

    /// Returns the fire date at the preferred hour. If the computed time is in the
    /// past, schedules for tomorrow at the preferred hour instead.
    private func normalizedFireDate(from base: Date, hour: Int, now: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = 0
        let candidate = calendar.date(from: comps) ?? base
        if candidate > now {
            return candidate
        }
        // Past due: schedule for tomorrow at the preferred hour.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var t = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        t.hour = hour
        t.minute = 0
        return calendar.date(from: t) ?? candidate
    }

    private func addRequest(id: String, title: String, body: String, fireDate: Date, calendar: Calendar) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAll() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Rich Notifications

    func scheduleInactivityReminder(rolls: [Roll]) {
        guard ReminderDefaults.enabled else { return }

        let calendar = Calendar.current
        var lastActive: Date?
        for roll in rolls {
            if lastActive == nil || roll.startDate > lastActive! { lastActive = roll.startDate }
            for frame in roll.frames ?? [] {
                guard let d = frame.capturedAt else { continue }
                if lastActive == nil || d > lastActive! { lastActive = d }
            }
        }
        guard let last = lastActive,
              let daysIdle = calendar.dateComponents([.day], from: last, to: Date()).day,
              daysIdle >= 7
        else { return }

        let fireDate = normalizedFireDate(
            from: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            hour: ReminderDefaults.hour,
            now: Date(),
            calendar: calendar
        )
        addRequest(
            id: "\(idPrefix)inactivity",
            title: L("Miss the smell of film?"),
            body: L("It's been %d days since your last shot. Time to load a new roll!", daysIdle),
            fireDate: fireDate,
            calendar: calendar
        )
    }

    private func lastAchievedKey(_ key: String) -> String { "lastNotified_\(key)" }

    func checkRollAchievements(rolls: [Roll]) {
        guard ReminderDefaults.enabled else { return }
        let ud = UserDefaults.standard

        let total = rolls.count
        let photos = rolls.reduce(0) { $0 + $1.filledFrames }
        let films = Set(rolls.map(\.filmName).filter { !$0.isEmpty }).count

        let rollGoals = [1, 10, 25, 50, 100]
        for goal in rollGoals where total >= goal {
            let key = "rolls_\(goal)"
            if !ud.bool(forKey: lastAchievedKey(key)) {
                ud.set(true, forKey: lastAchievedKey(key))
                let body = total == 1 ? L("You finished your first roll! The journey begins.") : L("You've shot %d rolls! Keep the film flowing.", total)
                fireAchievement(title: L("Achievement unlocked: %d rolls", goal), body: body)
            }
        }

        let photoGoals = [100, 500, 1000, 5000]
        for goal in photoGoals where photos >= goal {
            let key = "photos_\(goal)"
            if !ud.bool(forKey: lastAchievedKey(key)) {
                ud.set(true, forKey: lastAchievedKey(key))
                fireAchievement(title: L("Achievement unlocked: %d photos", goal), body: L("You've captured %d photos on film!", photos))
            }
        }

        let filmGoals = [5, 15, 30]
        for goal in filmGoals where films >= goal {
            let key = "films_\(goal)"
            if !ud.bool(forKey: lastAchievedKey(key)) {
                ud.set(true, forKey: lastAchievedKey(key))
                fireAchievement(title: L("Achievement unlocked: %d films", goal), body: L("You've shot %d different films — nice variety!", films))
            }
        }
    }

    private func fireAchievement(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        comps.second = comps.second.map { $0 + 2 }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(idPrefix)achievement.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}
