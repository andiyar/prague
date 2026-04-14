# Push Notifications Design — EAPragueC 2026

Local push notifications to remind users before their picked sessions start.

## Requirements

| Aspect | Decision |
|--------|----------|
| Timing | 15 minutes before session start |
| Scope | All picked sessions except posters |
| Re-schedule | On every pick change |
| Content | Title + venue + time |
| Tap action | Deep link to session detail |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ConferenceNavApp                        │
│  • Creates NotificationService, sets as delegate            │
│  • Injects into environment                                 │
│  • Observes selectedSessionId for navigation                │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────┐         ┌──────────────────────────┐
│   ConferenceStore    │         │   NotificationService    │
│                      │         │                          │
│ • myPicks: Set<Int>  │────────▶│ • requestPermission()    │
│ • togglePick()       │ calls   │ • scheduleNotifications()│
│ • myPickedSessions   │         │ • selectedSessionId      │
└──────────────────────┘         └──────────────────────────┘
                                              │
                                              ▼
                                 ┌──────────────────────────┐
                                 │ UNUserNotificationCenter │
                                 │ • Local notifications    │
                                 │ • Calendar triggers      │
                                 └──────────────────────────┘
```

**Flow:**
1. User picks/unpicks a session → `ConferenceStore.togglePick()`
2. ConferenceStore calls `NotificationService.scheduleNotifications(for: myPickedSessions)`
3. NotificationService clears pending notifications and schedules new ones
4. User taps notification → delegate extracts session ID → publishes to `selectedSessionId`
5. App observes `selectedSessionId` and navigates to SessionDetailView

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `ConferenceNav/Services/NotificationService.swift` | Permission, scheduling, delegate, deep link state |
| Modify | `ConferenceNav/Services/ConferenceStore.swift` | Call notification service when picks change |
| Modify | `ConferenceNav/ConferenceNavApp.swift` | Wire delegate, inject service, handle navigation |
| Modify | `ConferenceNav/Views/ContentView.swift` | Observe selectedSessionId, navigate to session |
| Modify | `ConferenceNav/project.yml` | Add notification usage description (optional) |

## NotificationService Component

**File:** `ConferenceNav/Services/NotificationService.swift`

```swift
import Foundation
import UserNotifications

@Observable
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var isAuthorized = false
    var selectedSessionId: Int?  // For deep link navigation
    
    func requestPermission() async {
        // Request .alert, .sound, .badge
        // Set isAuthorized based on result
    }
    
    func scheduleNotifications(for sessions: [Session]) {
        // 1. Remove all pending notification requests
        // 2. Filter: exclude .poster type
        // 3. Filter: exclude sessions where (startDate - 15min) < now
        // 4. For each remaining session, schedule notification
    }
    
    func sendTestNotification(for session: Session) {
        // Schedule for 3 seconds from now (debug/test mode)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Extract sessionId from userInfo
        // Set selectedSessionId
        // Call completionHandler
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is foreground
        completionHandler([.banner, .sound])
    }
}
```

### Notification Details

| Field | Value |
|-------|-------|
| Identifier | `"session-\(session.id)"` |
| Title | `"Starting in 15 min"` |
| Body | `"\(session.title) • \(session.venue) • \(session.startsAt)"` |
| Sound | `.default` |
| Trigger | `UNCalendarNotificationTrigger` at `startDate - 15 minutes` |
| UserInfo | `["sessionId": session.id]` |

## ConferenceStore Integration

Add notification service reference and trigger rescheduling on pick changes:

```swift
class ConferenceStore {
    var notificationService: NotificationService?
    
    var myPicks: Set<Int> = [] {
        didSet {
            savePicksLocally()
            rescheduleNotifications()
        }
    }
    
    private func rescheduleNotifications() {
        let sessions = myPickedSessions
        notificationService?.scheduleNotifications(for: sessions)
    }
}
```

## App Entry Point Integration

Wire up delegate and handle deep link navigation:

```swift
@main
struct ConferenceNavApp: App {
    @State private var store = ConferenceStore()
    @State private var notificationService = NotificationService()
    
    init() {
        // Set delegate before any notifications arrive
        UNUserNotificationCenter.current().delegate = notificationService
        store.notificationService = notificationService
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(notificationService)
        }
    }
}
```

## Deep Link Navigation

ContentView observes `selectedSessionId` and navigates:

```swift
struct ContentView: View {
    @Environment(NotificationService.self) var notificationService
    @Environment(ConferenceStore.self) var store
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                ScheduleView()
                    .navigationDestination(for: Session.self) { session in
                        SessionDetailView(session: session)
                    }
            }
            .tabItem { /* Schedule */ }
            .tag(0)
            // ... other tabs
        }
        .onChange(of: notificationService.selectedSessionId) { _, sessionId in
            guard let sessionId,
                  let session = store.sessions.first(where: { $0.id == sessionId }) else { return }
            selectedTab = 0
            navigationPath.append(session)
            notificationService.selectedSessionId = nil
        }
    }
}
```

## Permission Request

Request permission on first app launch:

```swift
// In ContentView or after splash screen
.task {
    await notificationService.requestPermission()
}
```

## Test Mode

Add debug button to trigger immediate test notification:

```swift
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
```

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Session already started | Skip scheduling (startDate - 15min < now) |
| Permission denied | `isAuthorized = false`, no scheduling attempted |
| App killed, notification tapped | App launches, delegate fires, navigation works |
| Pick removed | Next `scheduleNotifications` clears all and re-schedules remaining |
| Same session picked twice | Identifier `"session-\(id)"` overwrites previous |
| Poster session picked | Filtered out, no notification scheduled |

## Out of Scope

- User-configurable reminder timing (fixed at 15 min)
- Settings UI for notifications
- Remote push notifications (local only)
- Badge count management
