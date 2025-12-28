import SwiftUI
import UserNotifications

struct NotificationHelper {
    static let weekdayMessages = [
        1: "Start your week with a fun fact! 🎉",           // Sunday
        2: "Happy Monday! Ready for something new?",         // Monday
        3: "Trivia Tuesday! Did you know…",                  // Tuesday
        4: "Happy Wednesday!",                   // Wednesday
        5: "Happy Thursday!",// Thursday
        6: "Happy Friday! Time for a cool discovery!",       // Friday
        7: "Enjoy your Saturday with a little knowledge!"    // Saturday
    ]

    static func requestPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion(granted)
        }
    }
    static func scheduleWeeklyNotifications(hour: Int, minute: Int, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        for weekday in 1...7 {
            let content = UNMutableNotificationContent()
            content.title = NotificationHelper.weekdayMessages[weekday] ?? " Open AHA! Daily"
            content.body = "Open Aha! and see why today is special! Tap for some fun facts & games."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.weekday = weekday 
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "nationalDay-\(weekday)", content: content, trigger: trigger)
            center.add(request)
        }
    }
}
