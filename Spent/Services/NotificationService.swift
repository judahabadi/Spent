import Foundation
import UserNotifications

@Observable
final class NotificationService {
    var isAuthorized = false
    var scheduledTime: DateComponents = DateComponents(hour: 20, minute: 0)

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await MainActor.run { isAuthorized = granted }
        } catch {
            await MainActor.run { isAuthorized = false }
        }
    }

    // Schedule daily receipt notification
    func scheduleDailyNotification(receipt: DailyReceipt, at time: DateComponents) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-receipt"])

        let content = UNMutableNotificationContent()
        content.title = "Your daily receipt is ready"
        content.body = dailyNotificationBody(for: receipt)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-receipt", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // Schedule weekly summary
    func scheduleWeeklySummary(totalSpent: Double, totalInvested: Double) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-summary"])

        let content = UNMutableNotificationContent()
        content.title = "Your weekly receipt is ready"
        content.body = String(format: "Weekly receipt ready. $%.2f spent, $%.2f invested.", totalSpent, totalInvested)
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 8
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // Send streak milestone notification
    func notifyStreakMilestone(_ days: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Streak milestone!"
        content.body = "\(days) days in profit. Keep it up."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("success.caf"))

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "streak-\(days)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func dailyNotificationBody(for receipt: DailyReceipt) -> String {
        let net = receipt.netTotal
        let topApp = receipt.spentApps.sorted { $0.minutes > $1.minutes }.first?.displayName ?? "your apps"
        if net > 0 {
            return String(format: "You spent $%.2f today. %@ took most of it.", net, topApp)
        } else {
            return String(format: "You earned $%.2f today. Great work!", abs(net))
        }
    }
}
