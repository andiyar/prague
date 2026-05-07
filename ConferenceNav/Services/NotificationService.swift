import Foundation
import UserNotifications

@Observable
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var isAuthorized = false
    var selectedSessionId: Int?

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                isAuthorized = granted
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    // MARK: - Scheduling

    func scheduleNotifications(for sessions: [Session]) {
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let reminderInterval: TimeInterval = -15 * 60  // 15 min before

        // Schedule against Prague time, NOT the device's current timezone.
        // Otherwise: Ben schedules in Sydney (UTC+10), the trigger captures
        // components in Sydney-local time. Once he lands in Prague (UTC+2),
        // the device timezone shifts and the trigger fires ~8 hours late
        // because UNCalendarNotificationTrigger interprets timezone-less
        // components in the device's CURRENT timezone at fire time. Pinning
        // the components to Europe/Prague makes the trigger fire at the
        // correct absolute moment regardless of where the device is.
        let praguTimezone = TimeZone(identifier: "Europe/Prague") ?? TimeZone.current
        var praguCalendar = Calendar(identifier: .gregorian)
        praguCalendar.timeZone = praguTimezone

        for session in sessions {
            // Skip posters
            guard session.type != .poster else { continue }

            // Skip if notification time has passed
            guard let startDate = session.startDate else { continue }
            let notificationDate = startDate.addingTimeInterval(reminderInterval)
            guard notificationDate > now else { continue }

            // Create notification
            let content = UNMutableNotificationContent()
            content.title = "Starting in 15 min"
            content.body = "\(session.title) • \(session.venue) • \(session.startsAt)"
            content.sound = .default
            content.userInfo = ["sessionId": session.id]

            var components = praguCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            )
            components.timeZone = praguTimezone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "session-\(session.id)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }
    }

    // MARK: - Test Mode

    func sendTestNotification(for session: Session) {
        let content = UNMutableNotificationContent()
        content.title = "Starting in 15 min"
        content.body = "\(session.title) • \(session.venue) • \(session.startsAt)"
        content.sound = .default
        content.userInfo = ["sessionId": session.id]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(session.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let sessionId = response.notification.request.content.userInfo["sessionId"] as? Int {
            Task { @MainActor in
                selectedSessionId = sessionId
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
