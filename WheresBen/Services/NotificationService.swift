import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var deviceToken: String?

    private init() {}

    // MARK: - Permission Request

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted

            if granted {
                await registerForRemoteNotifications()
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Token Registration

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        print("📱 Device token: \(token)")

        // Register with Supabase
        Task {
            await registerTokenWithSupabase(token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        print("❌ Push registration failed: \(error)")
    }

    private func registerTokenWithSupabase(_ token: String) async {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        do {
            try await SupabaseClient.shared.registerPushToken(deviceId: deviceId, token: token)
            print("✅ Token registered with Supabase")
        } catch {
            print("❌ Failed to register token: \(error)")
        }
    }

    // MARK: - Local Notifications (for testing)

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ben says:"
        content.body = "Just landed in Dubai! 🛬"
        content.sound = .default

        let identifier = "test-notification-\(UUID().uuidString)"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)

        // Auto-remove from notification center after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }

    // MARK: - Schedule Local Notifications from Trip Data

    func scheduleFlightNotifications(for segments: [TripSegment]) {
        // Clear existing scheduled notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for segment in segments where segment.isFlying {
            // Schedule departure notification (30 mins before)
            if let flightNumber = segment.flightNumber {
                scheduleDepartureNotification(
                    flightNumber: flightNumber,
                    from: airportName(segment.flightFrom),
                    departureTime: segment.startTime
                )

                // Schedule landing notification (30 mins before arrival)
                scheduleLandingNotification(
                    flightNumber: flightNumber,
                    to: airportName(segment.flightTo),
                    arrivalTime: segment.endTime
                )
            }
        }
    }

    private func scheduleDepartureNotification(flightNumber: String, from: String, departureTime: Date) {
        let notificationTime = departureTime.addingTimeInterval(-30 * 60) // 30 mins before

        guard notificationTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Flight Update ✈️"
        content.body = "Ben's flight \(flightNumber) departs from \(from) in 30 minutes"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "departure-\(flightNumber)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleLandingNotification(flightNumber: String, to: String, arrivalTime: Date) {
        let notificationTime = arrivalTime.addingTimeInterval(-30 * 60) // 30 mins before

        guard notificationTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Landing Soon 🛬"
        content.body = "Ben should be landing in \(to) in about 30 minutes!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "landing-\(flightNumber)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func airportName(_ code: String?) -> String {
        switch code {
        case "SYD": return "Sydney"
        case "DXB": return "Dubai"
        case "PRG": return "Prague"
        default: return code ?? "airport"
        }
    }
}
