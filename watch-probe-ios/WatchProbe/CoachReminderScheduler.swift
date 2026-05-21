import Foundation
import UserNotifications

final class CoachReminderScheduler {
    static let shared = CoachReminderScheduler()

    private let reminderIdentifier = "ai-coach-morning-sync"

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
}
