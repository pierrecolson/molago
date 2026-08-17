import UserNotifications

/// Retire l'ancien rappel quotidien lors de la migration vers la bibliothèque
/// alimentée uniquement par les imports.
enum MorningCall {
    static func disable() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["molago.morning"])
        center.removeDeliveredNotifications(withIdentifiers: ["molago.morning"])
    }
}
