# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local push notifications that remind users 15 minutes before their picked sessions start (excluding posters), with deep linking to session detail on tap.

**Architecture:** NotificationService handles permission, scheduling, and delegate callbacks. ConferenceStore calls it when picks change. MainTabView observes selectedSessionId and navigates to the session detail.

**Tech Stack:** SwiftUI, UserNotifications framework, UNUserNotificationCenter

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `ConferenceNav/Services/NotificationService.swift` | Permission requests, scheduling notifications, delegate handling, deep link state |
| Modify | `ConferenceNav/Services/ConferenceStore.swift` | Add notificationService reference, call scheduleNotifications on pick changes |
| Modify | `ConferenceNav/ConferenceNavApp.swift` | Create NotificationService, set delegate in init, inject into environment |
| Modify | `ConferenceNav/Views/MainTabView.swift` | Add selectedTab binding, observe selectedSessionId for deep linking |
| Modify | `ConferenceNav/Views/ScheduleView.swift` | Accept optional navigationPath binding for programmatic navigation |

---

## Task 1: Create NotificationService

**Files:**
- Create: `ConferenceNav/Services/NotificationService.swift`

This task creates the core notification service with permission handling, scheduling, and delegate methods.

- [ ] **Step 1: Create NotificationService.swift with basic structure**

```swift
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
            
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            )
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
```

- [ ] **Step 2: Verify file compiles**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodegen generate && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
cd /Users/andiyar/developer/wheresben && git add ConferenceNav/Services/NotificationService.swift && git commit -m "feat: add NotificationService for session reminders"
```

---

## Task 2: Integrate NotificationService into ConferenceStore

**Files:**
- Modify: `ConferenceNav/Services/ConferenceStore.swift`

Add a reference to NotificationService and call it when picks change.

- [ ] **Step 1: Add notificationService property to ConferenceStore**

In `ConferenceNav/Services/ConferenceStore.swift`, add after line 8 (after `let lastUpdated = "12 April 2026"`):

```swift
    // MARK: - Notifications
    var notificationService: NotificationService?
```

- [ ] **Step 2: Add rescheduleNotifications method**

Add before the `// MARK: - Init` section (around line 17):

```swift
    private func rescheduleNotifications() {
        notificationService?.scheduleNotifications(for: myPickedSessions)
    }
```

- [ ] **Step 3: Call rescheduleNotifications in myPicks didSet**

Replace the `myPicks` property (lines 11-13) with:

```swift
    var myPicks: Set<Int> = [] {
        didSet {
            savePicksLocally()
            rescheduleNotifications()
        }
    }
```

- [ ] **Step 4: Verify build succeeds**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
cd /Users/andiyar/developer/wheresben && git add ConferenceNav/Services/ConferenceStore.swift && git commit -m "feat: wire ConferenceStore to NotificationService"
```

---

## Task 3: Wire NotificationService in ConferenceNavApp

**Files:**
- Modify: `ConferenceNav/ConferenceNavApp.swift`

Create the notification service, set it as delegate, and inject into environment.

- [ ] **Step 1: Add UserNotifications import**

At the top of `ConferenceNav/ConferenceNavApp.swift`, add after `import SwiftUI`:

```swift
import UserNotifications
```

- [ ] **Step 2: Add notificationService state**

After line 5 (`@State private var store = ConferenceStore()`), add:

```swift
    @State private var notificationService = NotificationService()
```

- [ ] **Step 3: Add init() to wire delegate and service**

After the state properties (around line 10), add:

```swift
    init() {
        // Wire notification service to store
        // Note: We need to do this after @State initialization, so we use a trick
        _store = State(initialValue: ConferenceStore())
        _notificationService = State(initialValue: NotificationService())
        
        // Set delegate (must happen before any notifications arrive)
        UNUserNotificationCenter.current().delegate = _notificationService.wrappedValue
        
        // Connect store to notification service
        _store.wrappedValue.notificationService = _notificationService.wrappedValue
    }
```

- [ ] **Step 4: Inject notificationService into environment**

In the body, add `.environment(notificationService)` after the existing `.environment(notesStore ?? ...)` line (around line 29). Find:

```swift
                .environment(notesStore ?? NotesStore(userId: savedUserId ?? "default"))
```

Add after it:

```swift
                .environment(notificationService)
```

- [ ] **Step 5: Request permission after splash screen**

Find the `.task` modifier that calls `store.syncPicks()` (around line 42). Modify it to also request notification permission:

```swift
                .task {
                    if savedUserId != nil {
                        await store.syncPicks()
                        await notificationService.requestPermission()
                    }
                }
```

- [ ] **Step 6: Verify build succeeds**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
cd /Users/andiyar/developer/wheresben && git add ConferenceNav/ConferenceNavApp.swift && git commit -m "feat: wire NotificationService delegate and environment"
```

---

## Task 4: Add Deep Link Navigation to MainTabView

**Files:**
- Modify: `ConferenceNav/Views/MainTabView.swift`

Add tab selection state and observe selectedSessionId for deep linking.

- [ ] **Step 1: Add environment and state properties**

Replace the current MainTabView struct (entire file) with:

```swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ConferenceStore.self) var store
    @Environment(NotificationService.self) var notificationService
    
    @State private var selectedTab = 0
    @State private var navigateToSessionId: Int?

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView(navigateToSessionId: $navigateToSessionId)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            MyPicksView()
                .tabItem {
                    Label("My Picks", systemImage: "star.fill")
                }
                .tag(2)

            ExtrasView()
                .tabItem {
                    Label("Extras", systemImage: "ellipsis.circle.fill")
                }
                .tag(3)
        }
        .tint(CNColors.navy(for: colorScheme))
        .onChange(of: notificationService.selectedSessionId) { _, sessionId in
            guard let sessionId else { return }
            // Switch to Schedule tab and navigate to session
            selectedTab = 0
            navigateToSessionId = sessionId
            // Clear the selection
            notificationService.selectedSessionId = nil
        }
    }
}
```

- [ ] **Step 2: Verify build (will fail - ScheduleView needs update)**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: Error about ScheduleView initializer (we'll fix in next task)

- [ ] **Step 3: Commit MainTabView changes**

```bash
cd /Users/andiyar/developer/wheresben && git add ConferenceNav/Views/MainTabView.swift && git commit -m "feat: add deep link navigation handling to MainTabView"
```

---

## Task 5: Update ScheduleView for Programmatic Navigation

**Files:**
- Modify: `ConferenceNav/Views/ScheduleView.swift`

Accept optional binding for programmatic navigation from notifications.

- [ ] **Step 1: Add navigateToSessionId binding parameter**

At the top of ScheduleView struct, add after the @State properties (around line 10):

```swift
    @Binding var navigateToSessionId: Int?
```

- [ ] **Step 2: Add navigation path state**

Add after the new binding:

```swift
    @State private var navigationPath = NavigationPath()
```

- [ ] **Step 3: Replace NavigationStack with path-based version**

Replace the `NavigationStack {` line (around line 12) with:

```swift
        NavigationStack(path: $navigationPath) {
```

- [ ] **Step 4: Add onChange to handle deep link navigation**

After the `.navigationDestination(for: Int.self)` modifier (around line 84), add:

```swift
            .onChange(of: navigateToSessionId) { _, sessionId in
                guard let sessionId else { return }
                navigationPath.append(sessionId)
                navigateToSessionId = nil
            }
```

- [ ] **Step 5: Add default value for navigateToSessionId binding**

After the closing brace of ScheduleView struct, add an extension with a convenience initializer:

```swift
extension ScheduleView {
    init() {
        self._navigateToSessionId = .constant(nil)
    }
}
```

- [ ] **Step 6: Verify build succeeds**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
cd /Users/andiyar/developer/wheresben && git add ConferenceNav/Views/ScheduleView.swift && git commit -m "feat: add programmatic navigation support to ScheduleView"
```

---

## Task 6: Test on Simulator

**Files:** None (manual testing)

Test the notification flow on the iOS Simulator.

- [ ] **Step 1: Build and run on simulator**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Then open Simulator and run the app manually, or:

```bash
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install "iPhone 16" $(find ~/Library/Developer/Xcode/DerivedData -name "ConferenceNav.app" -type d | head -1)
xcrun simctl launch "iPhone 16" com.wheresBen.ConferenceNav
```

- [ ] **Step 2: Grant notification permission**

When the app launches, tap "Allow" on the notification permission dialog.

- [ ] **Step 3: Pick a session**

Navigate to Schedule tab, tap on any non-poster session, tap the star to pick it.

- [ ] **Step 4: Verify notification is scheduled**

In a new terminal, check pending notifications:

```bash
# The app schedules notifications 15 min before session start
# Since conference is May 2026, notifications won't fire now
# But we can add a test notification method call for verification
```

- [ ] **Step 5: Add debug test button (optional)**

If you want to test the notification flow immediately, add a test button to SessionDetailView that calls `notificationService.sendTestNotification(for: session)`. This will fire in 3 seconds.

---

## Task 7: Final Verification and Cleanup

**Files:** None

- [ ] **Step 1: Run full build**

```bash
cd /Users/andiyar/developer/wheresben/ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' clean build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Verify all commits**

```bash
cd /Users/andiyar/developer/wheresben && git log --oneline -5
```

Expected: See commits for NotificationService, ConferenceStore, ConferenceNavApp, MainTabView, ScheduleView

- [ ] **Step 3: Update CLAUDE.md**

Add to the V3 section in CLAUDE.md that push notifications are implemented:

Find the `### V3 Roadmap` section and update it to show push notifications as complete.
