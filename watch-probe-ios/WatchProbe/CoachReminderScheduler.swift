import Foundation
import UserNotifications

final class CoachReminderScheduler {
    static let shared = CoachReminderScheduler()

    private let reminderIdentifier = "ai-coach-morning-sync"
    private let actionIdentifierPrefix = "ai-coach-action-"

    private init() {}

    func requestAuthorizationAndSchedule(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                self.scheduleMorningSyncReminder()
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func scheduleMorningSyncReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Sync your watch"
        content.body = "Open AI Coach so your watch data can sync and the coach can analyze what changed."
        content.sound = .default

        var components = DateComponents()
        components.hour = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleActionReminders(for action: CoachSuggestedAction, completion: @escaping (Bool, String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral else {
                DispatchQueue.main.async {
                    completion(false, "Notifications are not allowed.")
                }
                return
            }

            self.cancelActionReminders(actionId: action.id)
            let dates = self.reminderDates(for: action)
            guard !dates.isEmpty else {
                DispatchQueue.main.async {
                    completion(false, "No reminder times fit the current plan.")
                }
                return
            }

            for (index, date) in dates.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = action.category == "hydration" ? "Hydration check" : "AI Coach action"
                content.body = action.reminderPlan?.message.isEmpty == false ? action.reminderPlan?.message ?? action.title : action.title
                content.sound = .default

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(self.actionIdentifierPrefix)\(action.id)-\(index)",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request)
            }

            DispatchQueue.main.async {
                completion(true, "Scheduled \(dates.count) reminder\(dates.count == 1 ? "" : "s").")
            }
        }
    }

    func cancelActionReminders(actionId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [actionIdentifierPrefix] requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("\(actionIdentifierPrefix)\(actionId)-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private func reminderDates(for action: CoachSuggestedAction) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startHour = hour(from: action.reminderPlan?.startTime) ?? 9
        let endHour = hour(from: action.reminderPlan?.endTime) ?? 20
        let maxPerDay = max(1, min(action.reminderPlan?.maxPerDay ?? defaultMaxPerDay(for: action), 8))
        let intervalMinutes = cadenceMinutes(for: action)
        var dates: [Date] = []

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  var cursor = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
                  let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day) else { continue }

            var addedToday = 0
            if cursor < now.addingTimeInterval(30 * 60) {
                cursor = now.addingTimeInterval(60 * 60)
            }
            while cursor < end, addedToday < maxPerDay, dates.count < 48 {
                dates.append(cursor)
                addedToday += 1
                cursor = calendar.date(byAdding: .minute, value: intervalMinutes, to: cursor) ?? end
            }
        }
        return dates
    }

    private func cadenceMinutes(for action: CoachSuggestedAction) -> Int {
        let cadence = action.notificationCadence.lowercased()
        if cadence.contains("90") { return 90 }
        if cadence.contains("2") || cadence.contains("120") { return 120 }
        if cadence.contains("hour") { return 60 }
        if action.category == "hydration" { return 120 }
        return 24 * 60
    }

    private func defaultMaxPerDay(for action: CoachSuggestedAction) -> Int {
        switch action.category {
        case "hydration": return 5
        case "activity": return 2
        default: return 1
        }
    }

    private func hour(from text: String?) -> Int? {
        guard let text, !text.isEmpty else { return nil }
        let parts = text.split(separator: ":")
        guard let first = parts.first, let hour = Int(first) else { return nil }
        return min(23, max(0, hour))
    }
}
