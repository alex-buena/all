import Foundation
import UserNotifications

enum ReminderScheduler {
    static let reminderIdentifier = "weeklySnapshotReminder"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func scheduleWeeklyReminder(weekday: Int, time: Date) async {
        let center = UNUserNotificationCenter.current()
        await cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = "Weekly snapshot"
        content.body = "Log your account balances to update your net worth."
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Ignore scheduling errors for now.
        }
    }

    static func cancelReminder() async {
        await UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }
}
