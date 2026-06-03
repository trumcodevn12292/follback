import Foundation
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
                // Nudge if a roll has been "in progress" for too long.
                let base = calendar.date(byAdding: .day, value: staleDays, to: roll.startDate) ?? roll.startDate
                let fireDate = normalizedFireDate(from: base, hour: hour, now: now, calendar: calendar)
                addRequest(
                    id: "\(idPrefix)stale.\(roll.id.uuidString)",
                    title: "Still shooting \(roll.filmName)?",
                    body: "This roll has been in progress for a while. \(roll.filledFrames)/\(roll.capacity) frames so far.",
                    fireDate: fireDate,
                    calendar: calendar
                )
            case .completed:
                // Remind to get a finished roll developed.
                let base = calendar.date(byAdding: .day, value: developDays, to: roll.updatedAt) ?? roll.updatedAt
                let fireDate = normalizedFireDate(from: base, hour: hour, now: now, calendar: calendar)
                addRequest(
                    id: "\(idPrefix)develop.\(roll.id.uuidString)",
                    title: "Time to develop \(roll.filmName)",
                    body: "You finished this roll. Drop it off at the lab so you don't forget.",
                    fireDate: fireDate,
                    calendar: calendar
                )
            case .developed, .archived:
                break
            }
        }
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
}
