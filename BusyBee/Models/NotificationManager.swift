import Foundation
import Combine
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    static let shared = NotificationManager()
    
    private init() {
        requestPermission()
    }
    
    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func updateMorningReminders(enabled: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning-reminder"])
        
        guard enabled else { return }
        
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
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Over Budget!"
        
        // Secret Easter egg for the first deficit (one-time only)
        let hasShownEasterEgg = UserDefaults.standard.bool(forKey: "hasShownEasterEgg")
        if !hasShownEasterEgg {
            content.body = "Uh oh, Lucy's got some 'splaining to do! 😄"
            UserDefaults.standard.set(true, forKey: "hasShownEasterEgg")
        } else {
            content.body = "You're \(abs(remaining).currencyString) over your daily limit. Tomorrow is a fresh start!"
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "deficit-alert-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Deficit alert error: \(error)")
            }
        }
    }
}
