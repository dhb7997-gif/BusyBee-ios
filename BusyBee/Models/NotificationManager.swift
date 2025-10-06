import Foundation
import Combine
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    static let shared = NotificationManager()

    private init() {}
    
    func updateMorningReminders(enabled: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning-reminder"])
        
        guard enabled else { return }

        requestPermissionIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Good Morning! 🌅"
        content.body = "Check your daily budget and start the day right!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Morning reminder error: \(error)")
            }
        }
    }
    
    func updateEndOfDaySummary(enabled: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["end-of-day-summary"])
        
        guard enabled else { return }

        requestPermissionIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "End of Day Summary 📊"
        content.body = "How did you do with your budget today?"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "end-of-day-summary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("End of day summary error: \(error)")
            }
        }
    }
    
    func sendDeficitAlert(remaining: Decimal, totalSpent: Decimal) {
        NotificationCenter.default.post(name: Self.deficitNotificationName, object: nil, userInfo: [
            "amount": remaining,
            "totalSpent": totalSpent
        ])
    }

    static let deficitNotificationName = Notification.Name("com.busybee.deficitAlert")

    private var permissionRequested = false

    private func requestPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
