# ConferenceNav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS conference navigator app for EAPC 2026 that lets two users browse, search, and build personal programmes with shared pick visibility.

**Architecture:** New SwiftUI target in existing WheresBen.xcodeproj. Bundled JSON for programme data, Supabase for pick sync between two users. Four-tab navigation (Schedule / Search / My Picks / Mates) with shared session card component.

**Tech Stack:** SwiftUI, iOS 17+, Supabase REST API (existing client), bundled JSON, UserDefaults

---

## File Map

| File | Responsibility |
|------|---------------|
| `ConferenceNav/ConferenceNavApp.swift` | App entry, user identity gate |
| `ConferenceNav/Models/Session.swift` | Session, Presentation, Author, SessionType models |
| `ConferenceNav/Models/UserProfile.swift` | Ben/Ron user identity |
| `ConferenceNav/Design/ConferenceDesign.swift` | Colour palette, typography, component styles |
| `ConferenceNav/Services/ConferenceStore.swift` | Central state: sessions, picks, conflicts |
| `ConferenceNav/Services/SearchIndex.swift` | Full-text search index |
| `ConferenceNav/Services/PicksSyncService.swift` | Supabase pick CRUD |
| `ConferenceNav/Views/MainTabView.swift` | Four-tab container |
| `ConferenceNav/Views/ScheduleView.swift` | Tab 1: day timeline with filters |
| `ConferenceNav/Views/SearchView.swift` | Tab 2: search + filter |
| `ConferenceNav/Views/MyPicksView.swift` | Tab 3: personal programme |
| `ConferenceNav/Views/MatesView.swift` | Tab 4: mate's picks |
| `ConferenceNav/Views/SessionDetailView.swift` | Push detail view |
| `ConferenceNav/Views/SessionCardView.swift` | Reusable session card |
| `ConferenceNav/Views/Components/DayPicker.swift` | Day pill selector |
| `ConferenceNav/Views/Components/TypeBadge.swift` | Session type pill |
| `ConferenceNav/Views/Components/MateBadges.swift` | B/R pick badges |
| `ConferenceNav/Views/Components/PickButton.swift` | Gold star toggle |
| `ConferenceNav/Views/Components/ConflictBanner.swift` | Overlap warning |
| `ConferenceNav/Views/Components/FilterChips.swift` | Scrollable filter pills |
| `ConferenceNav/Views/UserPickerView.swift` | First-launch "Who are you?" |
| `ConferenceNav/Resources/programme.json` | Bundled conference data |
| `ConferenceNav/Assets.xcassets/` | App icon, colour assets |

---

### Task 1: Xcode Target & Project Scaffold

**Files:**
- Create: `ConferenceNav/ConferenceNavApp.swift`
- Create: `ConferenceNav/Assets.xcassets/` (via Xcode)
- Modify: `WheresBen.xcodeproj/project.pbxproj`

This task must be done in Xcode to correctly configure the target. The steps below describe what to do in Xcode's UI.

- [ ] **Step 1: Create target folder structure**

```bash
cd /Users/andiyar/Developer/WheresBen
mkdir -p ConferenceNav/Models
mkdir -p ConferenceNav/Services
mkdir -p ConferenceNav/Design
mkdir -p ConferenceNav/Views/Components
mkdir -p ConferenceNav/Resources
```

- [ ] **Step 2: Create minimal app entry point**

Create `ConferenceNav/ConferenceNavApp.swift`:

```swift
import SwiftUI

@main
struct ConferenceNavApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ConferenceNav")
        }
    }
}
```

- [ ] **Step 3: Add new target in Xcode**

Open `WheresBen.xcodeproj` in Xcode. File → New → Target → iOS App.
- Product Name: `ConferenceNav`
- Interface: SwiftUI
- Language: Swift
- Bundle Identifier: `com.wheresBen.ConferenceNav`
- Deployment Target: iOS 17.0

Delete the auto-generated files Xcode creates (ContentView.swift, Assets.xcassets if duplicate) and instead:
- Drag the `ConferenceNav/` folder into the Xcode project navigator under the ConferenceNav target
- Make sure `ConferenceNavApp.swift` is in the ConferenceNav target's Compile Sources
- Add `Shared/Services/SupabaseClient.swift` to the ConferenceNav target's Compile Sources (same file, additional target membership)

- [ ] **Step 4: Build and run to verify**

Run: Select ConferenceNav scheme → Build (⌘B)
Expected: Builds successfully, shows "ConferenceNav" text on screen.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ConferenceNav target scaffold"
```

---

### Task 2: Data Models

**Files:**
- Create: `ConferenceNav/Models/Session.swift`
- Create: `ConferenceNav/Models/UserProfile.swift`

- [ ] **Step 1: Create Session models**

Create `ConferenceNav/Models/Session.swift`:

```swift
import Foundation

enum SessionType: String, Codable, CaseIterable {
    case keynote = "Keynote"
    case oral = "Oral"
    case panel = "Panel"
    case poster = "Poster"
    case general = "General"
    case meeting = "Meeting"
    case social = "Social"
    case lunch = "Lunch"
    case tea = "Tea"       // Break
}

struct Session: Codable, Identifiable {
    let id: Int
    let day: String
    let date: String
    let title: String
    let type: SessionType
    let venue: String
    let startsAt: String
    let endsAt: String
    let startsAtIso: String
    let endsAtIso: String
    let description: String
    let chairs: [String]
    let presentationsCount: Int
    let presentations: [Presentation]
}

struct Presentation: Codable, Identifiable {
    let id: Int
    let title: String
    let startsAt: String
    let endsAt: String
    let durationMins: Int
    let presenter: String
    let authors: [Author]
}

struct Author: Codable {
    let name: String
    let organisation: String
    let presenting: Bool
}

// MARK: - Helpers

extension Session {
    /// Parse startsAtIso into a Date for conflict detection
    var startDate: Date? {
        ISO8601DateFormatter().date(from: startsAtIso)
    }

    var endDate: Date? {
        ISO8601DateFormatter().date(from: endsAtIso)
    }

    /// Human-readable day label
    var dayLabel: String {
        switch date {
        case "2026-05-14": return "Thu 14 May"
        case "2026-05-15": return "Fri 15 May"
        case "2026-05-16": return "Sat 16 May"
        default: return date
        }
    }

    /// Time slot label e.g. "09:00 - 10:30"
    var timeSlot: String {
        "\(startsAt) - \(endsAt)"
    }

    /// Whether this is a browseable session (not a break/lunch)
    var isBrowseable: Bool {
        switch type {
        case .tea, .lunch: return false
        default: return true
        }
    }

    /// Check if this session overlaps with another
    func conflicts(with other: Session) -> Bool {
        guard date == other.date,
              let s1 = startDate, let e1 = endDate,
              let s2 = other.startDate, let e2 = other.endDate else {
            return false
        }
        return s1 < e2 && s2 < e1
    }
}

extension SessionType {
    /// Display-friendly types for filter chips (excludes breaks/lunch)
    static var filterableTypes: [SessionType] {
        [.keynote, .oral, .panel, .poster, .general, .meeting]
    }
}
```

- [ ] **Step 2: Create UserProfile model**

Create `ConferenceNav/Models/UserProfile.swift`:

```swift
import Foundation

struct UserProfile: Equatable {
    let id: String
    let displayName: String
    let badge: String

    static let ben = UserProfile(id: "ben", displayName: "Ben", badge: "B")
    static let ron = UserProfile(id: "ron", displayName: "Ron", badge: "R")

    var mate: UserProfile {
        self == .ben ? .ron : .ben
    }
}
```

- [ ] **Step 3: Add files to Xcode target**

In Xcode, ensure both files are added to the ConferenceNav target's Compile Sources.

- [ ] **Step 4: Build to verify models compile**

Run: Select ConferenceNav scheme → Build (⌘B)
Expected: Builds successfully.

- [ ] **Step 5: Commit**

```bash
git add ConferenceNav/Models/
git commit -m "feat: add Session and UserProfile data models"
```

---

### Task 3: Bundled Programme JSON

**Files:**
- Create: `ConferenceNav/Resources/programme.json`

- [ ] **Step 1: Generate clean programme.json from extracted data**

The extracted data at `data/eapc/programme_structured.json` contains all 98 sessions. Copy it as the bundled resource:

```bash
cp data/eapc/programme_structured.json ConferenceNav/Resources/programme.json
```

- [ ] **Step 2: Verify JSON decodes with our models**

Create a quick test by temporarily adding to `ConferenceNavApp.swift`:

```swift
import SwiftUI

@main
struct ConferenceNavApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ConferenceNav")
                .task {
                    do {
                        guard let url = Bundle.main.url(forResource: "programme", withExtension: "json") else {
                            print("ERROR: programme.json not found in bundle")
                            return
                        }
                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let sessions = try decoder.decode([Session].self, from: data)
                        print("SUCCESS: Loaded \(sessions.count) sessions")
                        let browseable = sessions.filter(\.isBrowseable)
                        print("Browseable: \(browseable.count)")
                        let types = Set(sessions.map(\.type))
                        print("Types: \(types)")
                    } catch {
                        print("DECODE ERROR: \(error)")
                    }
                }
        }
    }
}
```

- [ ] **Step 3: Add programme.json to target resources in Xcode**

In Xcode, drag `ConferenceNav/Resources/programme.json` into the project navigator. Ensure it is added to ConferenceNav target's "Copy Bundle Resources" build phase.

- [ ] **Step 4: Run and verify decode**

Run: Select ConferenceNav scheme → Run (⌘R)
Expected console output:
```
SUCCESS: Loaded 98 sessions
Browseable: 87
Types: [keynote, oral, panel, poster, general, meeting, social, lunch, tea]
```

- [ ] **Step 5: Commit**

```bash
git add ConferenceNav/Resources/programme.json
git commit -m "feat: bundle programme.json with 98 sessions"
```

---

### Task 4: Design System

**Files:**
- Create: `ConferenceNav/Design/ConferenceDesign.swift`

- [ ] **Step 1: Create colour palette and typography**

Create `ConferenceNav/Design/ConferenceDesign.swift`:

```swift
import SwiftUI

// MARK: - Colour Palette

struct CNColors {
    // Adaptive colours using light/dark pairs
    static let background = Color("CNBackground", bundle: nil)
    static let surface = Color("CNSurface", bundle: nil)
    static let surfaceSecondary = Color("CNSurfaceSecondary", bundle: nil)

    // Since we don't want to depend on asset catalogs for colours,
    // use environment-adaptive computed properties instead
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "0D0D1A") : Color(hex: "FAFAF7")
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1A1A2E") : .white
    }

    static func surfaceSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "141425") : Color(hex: "F5F3EE")
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FAFAF7") : Color(hex: "22272B")
    }

    static let textSecondary = Color(hex: "8C8C8C")

    static func navy(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "4A7FD4") : Color(hex: "002664")
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FF4D6A") : Color(hex: "D7153A")
    }

    static func gold(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "E0B840") : Color(hex: "C9A227")
    }

    static func teal(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "3DBAD4") : Color(hex: "1B6B7D")
    }

    static func conflictAmber(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FFB340") : Color(hex: "E6940A")
    }

    // Type badge colours
    static func typeBadgeColor(for type: SessionType, scheme: ColorScheme) -> Color {
        switch type {
        case .keynote: return red(for: scheme)
        case .oral: return navy(for: scheme)
        case .panel: return teal(for: scheme)
        case .poster: return gold(for: scheme)
        case .general: return textSecondary
        case .meeting: return Color(hex: "BBBBBB")
        case .social: return teal(for: scheme)
        case .tea, .lunch: return textSecondary
        }
    }
}

// MARK: - Typography

struct CNFonts {
    /// Serif headline — New York
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Sans body — SF Pro
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Monospace for times
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Presets
    static let largeTitle = serif(28)
    static let title = serif(22)
    static let title2 = serif(18)
    static let headline = sans(16, weight: .semibold)
    static let body = sans(15)
    static let caption = sans(13)
    static let small = sans(11)
    static let time = mono(13, weight: .semibold)
    static let timeSmall = mono(11)
}

// MARK: - Card Style

struct CNCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var typeColor: Color = .clear
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(CNColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .leading) {
                if typeColor != .clear {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(typeColor)
                        .frame(width: 4)
                        .padding(.vertical, 6)
                }
            }
            .shadow(
                color: colorScheme == .dark
                    ? .clear
                    : .black.opacity(0.06),
                radius: 4, x: 0, y: 2
            )
    }
}

extension View {
    func cnCard(typeColor: Color = .clear, highlighted: Bool = false) -> some View {
        modifier(CNCardStyle(typeColor: typeColor, isHighlighted: highlighted))
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

- [ ] **Step 2: Add to Xcode target and build**

Ensure `ConferenceDesign.swift` is in ConferenceNav target. Build (⌘B).
Expected: Compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Design/
git commit -m "feat: add ConferenceNav design system (colours, fonts, card style)"
```

---

### Task 5: Conference Store (State Management)

**Files:**
- Create: `ConferenceNav/Services/ConferenceStore.swift`

- [ ] **Step 1: Create the central store**

Create `ConferenceNav/Services/ConferenceStore.swift`:

```swift
import SwiftUI

@Observable
class ConferenceStore {
    // MARK: - Data
    private(set) var sessions: [Session] = []
    var currentUser: UserProfile = .ben
    let lastUpdated = "12 April 2026"

    // MARK: - Picks
    var myPicks: Set<Int> = [] {
        didSet { savePicks() }
    }
    var matePicks: Set<Int> = []

    // MARK: - Init

    init() {
        loadSessions()
        loadPicks()
    }

    // MARK: - Session Loading

    private func loadSessions() {
        guard let url = Bundle.main.url(forResource: "programme", withExtension: "json") else {
            print("ERROR: programme.json not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            sessions = try decoder.decode([Session].self, from: data)
            print("Loaded \(sessions.count) sessions")
        } catch {
            print("Failed to decode programme.json: \(error)")
        }
    }

    // MARK: - Browseable Sessions

    var browseableSessions: [Session] {
        sessions.filter(\.isBrowseable)
    }

    /// All unique dates in order
    var dates: [String] {
        ["2026-05-14", "2026-05-15", "2026-05-16"]
    }

    /// Sessions for a given date, grouped by time slot
    func sessionsForDate(_ date: String) -> [String: [Session]] {
        let daySessions = browseableSessions.filter { $0.date == date }
        return Dictionary(grouping: daySessions) { $0.timeSlot }
    }

    /// Sorted time slot keys for a date
    func timeSlotsForDate(_ date: String) -> [String] {
        let groups = sessionsForDate(date)
        return groups.keys.sorted { a, b in
            let aStart = a.components(separatedBy: " - ").first ?? a
            let bStart = b.components(separatedBy: " - ").first ?? b
            return aStart < bStart
        }
    }

    // MARK: - All unique venues (for filter chips)

    var allVenues: [String] {
        let venues = Set(browseableSessions.map(\.venue))
        return venues.sorted()
    }

    // MARK: - Pick Management

    func isPicked(_ sessionId: Int) -> Bool {
        myPicks.contains(sessionId)
    }

    func isMatePicked(_ sessionId: Int) -> Bool {
        matePicks.contains(sessionId)
    }

    func togglePick(_ sessionId: Int) {
        if myPicks.contains(sessionId) {
            myPicks.remove(sessionId)
        } else {
            myPicks.insert(sessionId)
        }
    }

    // MARK: - My Picked Sessions

    var myPickedSessions: [Session] {
        browseableSessions
            .filter { myPicks.contains($0.id) }
            .sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    var matePickedSessions: [Session] {
        browseableSessions
            .filter { matePicks.contains($0.id) }
            .sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    var bothPickedSessions: [Session] {
        browseableSessions
            .filter { myPicks.contains($0.id) && matePicks.contains($0.id) }
            .sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    // MARK: - Conflict Detection

    func conflictingSession(for session: Session) -> Session? {
        let picked = myPickedSessions.filter { $0.date == session.date && $0.id != session.id }
        return picked.first { session.conflicts(with: $0) }
    }

    func hasConflict(_ session: Session) -> Bool {
        conflictingSession(for: session) != nil
    }

    // MARK: - Pick Summary

    func pickCount(for date: String) -> Int {
        myPickedSessions.filter { $0.date == date }.count
    }

    // MARK: - Local Persistence

    private var picksKey: String { "conferencePicks_\(currentUser.id)" }

    private func savePicks() {
        let array = Array(myPicks)
        UserDefaults.standard.set(array, forKey: picksKey)
    }

    private func loadPicks() {
        let array = UserDefaults.standard.array(forKey: picksKey) as? [Int] ?? []
        myPicks = Set(array)
    }

    func switchUser(to user: UserProfile) {
        // Save current picks before switching
        savePicks()
        currentUser = user
        loadPicks()
    }
}
```

- [ ] **Step 2: Wire store into app entry point**

Update `ConferenceNav/ConferenceNavApp.swift`:

```swift
import SwiftUI

@main
struct ConferenceNavApp: App {
    @State private var store = ConferenceStore()

    var body: some Scene {
        WindowGroup {
            Text("Sessions: \(store.sessions.count)")
                .environment(store)
        }
    }
}
```

- [ ] **Step 3: Build and run**

Run: ⌘R
Expected: Screen shows "Sessions: 98"

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/Services/ConferenceStore.swift ConferenceNav/ConferenceNavApp.swift
git commit -m "feat: add ConferenceStore with session loading, picks, and conflict detection"
```

---

### Task 6: UI Components

**Files:**
- Create: `ConferenceNav/Views/Components/DayPicker.swift`
- Create: `ConferenceNav/Views/Components/TypeBadge.swift`
- Create: `ConferenceNav/Views/Components/MateBadges.swift`
- Create: `ConferenceNav/Views/Components/PickButton.swift`
- Create: `ConferenceNav/Views/Components/ConflictBanner.swift`
- Create: `ConferenceNav/Views/Components/FilterChips.swift`

- [ ] **Step 1: Create DayPicker**

Create `ConferenceNav/Views/Components/DayPicker.swift`:

```swift
import SwiftUI

struct DayPicker: View {
    @Binding var selectedDate: String
    @Environment(\.colorScheme) var colorScheme

    private let days: [(date: String, label: String, short: String)] = [
        ("2026-05-14", "Thu 14 May", "THU"),
        ("2026-05-15", "Fri 15 May", "FRI"),
        ("2026-05-16", "Sat 16 May", "SAT"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.date) { day in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = day.date
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(day.short)
                            .font(CNFonts.sans(13, weight: .bold))
                        Text(day.label.replacingOccurrences(of: "\(day.short.prefix(1).uppercased() + day.short.dropFirst().lowercased()) ", with: ""))
                            .font(CNFonts.sans(10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedDate == day.date
                            ? CNColors.navy(for: colorScheme)
                            : CNColors.surfaceSecondary(for: colorScheme)
                    )
                    .foregroundStyle(
                        selectedDate == day.date
                            ? .white
                            : CNColors.textPrimary(for: colorScheme)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create TypeBadge**

Create `ConferenceNav/Views/Components/TypeBadge.swift`:

```swift
import SwiftUI

struct TypeBadge: View {
    let type: SessionType
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(type.rawValue)
            .font(CNFonts.sans(10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(CNColors.typeBadgeColor(for: type, scheme: colorScheme).opacity(0.15))
            .foregroundStyle(CNColors.typeBadgeColor(for: type, scheme: colorScheme))
            .clipShape(Capsule())
    }
}
```

- [ ] **Step 3: Create MateBadges**

Create `ConferenceNav/Views/Components/MateBadges.swift`:

```swift
import SwiftUI

struct MateBadges: View {
    let session: Session
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            if store.isPicked(session.id) {
                badge(store.currentUser.badge, color: CNColors.navy(for: colorScheme))
            }
            if store.isMatePicked(session.id) {
                badge(store.currentUser.mate.badge, color: CNColors.red(for: colorScheme))
            }
        }
    }

    private func badge(_ letter: String, color: Color) -> some View {
        Text(letter)
            .font(CNFonts.sans(10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 4: Create PickButton**

Create `ConferenceNav/Views/Components/PickButton.swift`:

```swift
import SwiftUI

struct PickButton: View {
    let sessionId: Int
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme
    @State private var animating = false

    var isPicked: Bool { store.isPicked(sessionId) }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                animating = true
            }
            store.togglePick(sessionId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animating = false
            }
        } label: {
            Image(systemName: isPicked ? "star.fill" : "star")
                .font(.system(size: 20))
                .foregroundStyle(
                    isPicked
                        ? CNColors.gold(for: colorScheme)
                        : CNColors.textSecondary
                )
                .scaleEffect(animating ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Create ConflictBanner**

Create `ConferenceNav/Views/Components/ConflictBanner.swift`:

```swift
import SwiftUI

struct ConflictBanner: View {
    let conflictingTitle: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text("Conflicts with \(conflictingTitle)")
                .font(CNFonts.small)
                .lineLimit(1)
        }
        .foregroundStyle(CNColors.conflictAmber(for: colorScheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CNColors.conflictAmber(for: colorScheme).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
```

- [ ] **Step 6: Create FilterChips**

Create `ConferenceNav/Views/Components/FilterChips.swift`:

```swift
import SwiftUI

struct FilterChips<T: Hashable>: View {
    let label: String
    let options: [T]
    @Binding var selected: Set<T>
    let title: (T) -> String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(label)
                    .font(CNFonts.sans(11, weight: .medium))
                    .foregroundStyle(CNColors.textSecondary)

                ForEach(Array(options), id: \.self) { option in
                    Button {
                        if selected.contains(option) {
                            selected.remove(option)
                        } else {
                            selected.insert(option)
                        }
                    } label: {
                        Text(title(option))
                            .font(CNFonts.sans(12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selected.contains(option)
                                    ? CNColors.navy(for: colorScheme)
                                    : CNColors.surfaceSecondary(for: colorScheme)
                            )
                            .foregroundStyle(
                                selected.contains(option)
                                    ? .white
                                    : CNColors.textPrimary(for: colorScheme)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
```

- [ ] **Step 7: Build to verify all components compile**

Run: ⌘B
Expected: Compiles cleanly.

- [ ] **Step 8: Commit**

```bash
git add ConferenceNav/Views/Components/
git commit -m "feat: add UI components (DayPicker, TypeBadge, MateBadges, PickButton, ConflictBanner, FilterChips)"
```

---

### Task 7: Session Card View

**Files:**
- Create: `ConferenceNav/Views/SessionCardView.swift`

- [ ] **Step 1: Create the reusable session card**

Create `ConferenceNav/Views/SessionCardView.swift`:

```swift
import SwiftUI

struct SessionCardView: View {
    let session: Session
    var showTime: Bool = false

    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: content
            VStack(alignment: .leading, spacing: 6) {
                // Type badge + time (if showing)
                HStack(spacing: 6) {
                    TypeBadge(type: session.type)
                    if showTime {
                        Text(session.timeSlot)
                            .font(CNFonts.timeSmall)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                }

                // Title
                Text(session.title)
                    .font(CNFonts.headline)
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    .lineLimit(2)

                // Venue + presentations
                HStack(spacing: 4) {
                    Text(session.venue)
                        .font(CNFonts.caption)
                        .foregroundStyle(CNColors.textSecondary)
                    if session.presentationsCount > 0 {
                        Text("·")
                            .foregroundStyle(CNColors.textSecondary)
                        Text("\(session.presentationsCount) talks")
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                }

                // Badges row
                HStack(spacing: 8) {
                    MateBadges(session: session)

                    if let conflict = store.conflictingSession(for: session),
                       store.isPicked(session.id) {
                        ConflictBanner(conflictingTitle: conflict.title)
                    }
                }
            }

            Spacer()

            // Right: pick star
            PickButton(sessionId: session.id)
        }
        .cnCard(typeColor: CNColors.typeBadgeColor(for: session.type, scheme: colorScheme))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: ⌘B
Expected: Compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SessionCardView.swift
git commit -m "feat: add SessionCardView with type badge, mate badges, pick star, and conflict banner"
```

---

### Task 8: Schedule View (Tab 1)

**Files:**
- Create: `ConferenceNav/Views/ScheduleView.swift`

- [ ] **Step 1: Create ScheduleView**

Create `ConferenceNav/Views/ScheduleView.swift`:

```swift
import SwiftUI

struct ScheduleView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedDate = "2026-05-14"
    @State private var selectedTypes: Set<SessionType> = []
    @State private var selectedVenues: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Day picker
                    DayPicker(selectedDate: $selectedDate)
                        .padding(.horizontal, 16)

                    // Filter chips
                    VStack(spacing: 4) {
                        FilterChips(
                            label: "Type",
                            options: SessionType.filterableTypes,
                            selected: $selectedTypes,
                            title: \.rawValue
                        )
                        FilterChips(
                            label: "Room",
                            options: store.allVenues,
                            selected: $selectedVenues,
                            title: { $0 }
                        )
                    }

                    // Time slots
                    let timeSlots = store.timeSlotsForDate(selectedDate)
                    ForEach(timeSlots, id: \.self) { slot in
                        let allSessions = store.sessionsForDate(selectedDate)[slot] ?? []
                        let filtered = applyFilters(allSessions)

                        VStack(alignment: .leading, spacing: 8) {
                            // Time slot header
                            HStack {
                                Text(slot)
                                    .font(CNFonts.time)
                                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                Text("· \(allSessions.count) parallel")
                                    .font(CNFonts.small)
                                    .foregroundStyle(CNColors.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            // Session cards
                            if filtered.isEmpty && !allSessions.isEmpty {
                                Text("No sessions match filters")
                                    .font(CNFonts.caption)
                                    .foregroundStyle(CNColors.textSecondary)
                                    .padding(.horizontal, 16)
                            } else {
                                ForEach(filtered) { session in
                                    NavigationLink(value: session.id) {
                                        SessionCardView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Schedule")
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
        }
    }

    private func applyFilters(_ sessions: [Session]) -> [Session] {
        sessions.filter { session in
            (selectedTypes.isEmpty || selectedTypes.contains(session.type)) &&
            (selectedVenues.isEmpty || selectedVenues.contains(session.venue))
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: ⌘B
Expected: May fail because `SessionDetailView` doesn't exist yet. Create a placeholder:

Create `ConferenceNav/Views/SessionDetailView.swift`:

```swift
import SwiftUI

struct SessionDetailView: View {
    let session: Session

    var body: some View {
        Text(session.title)
    }
}
```

Build again → should compile.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/ScheduleView.swift ConferenceNav/Views/SessionDetailView.swift
git commit -m "feat: add ScheduleView with day picker, filter chips, and time slot grouping"
```

---

### Task 9: Search View (Tab 2)

**Files:**
- Create: `ConferenceNav/Services/SearchIndex.swift`
- Create: `ConferenceNav/Views/SearchView.swift`

- [ ] **Step 1: Create SearchIndex**

Create `ConferenceNav/Services/SearchIndex.swift`:

```swift
import Foundation

struct SearchIndex {
    struct Entry {
        let sessionId: Int
        let text: String  // Normalised, concatenated searchable text
    }

    private var entries: [Entry] = []

    mutating func build(from sessions: [Session]) {
        entries = sessions.filter(\.isBrowseable).map { session in
            var parts: [String] = []

            // Session-level
            parts.append(session.title)
            parts.append(session.description)
            parts.append(session.venue)
            parts.append(session.type.rawValue)

            // Presentation-level
            for pres in session.presentations {
                parts.append(pres.title)
                parts.append(pres.presenter)
                for author in pres.authors {
                    parts.append(author.name)
                    parts.append(author.organisation)
                }
            }

            let combined = parts.joined(separator: " ")
            return Entry(sessionId: session.id, text: normalise(combined))
        }
    }

    func search(_ query: String) -> [Int] {
        let normalised = normalise(query)
        guard !normalised.isEmpty else { return [] }

        let terms = normalised.split(separator: " ").map(String.init)

        return entries
            .filter { entry in
                terms.allSatisfy { term in
                    entry.text.contains(term)
                }
            }
            .map(\.sessionId)
    }

    private func normalise(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
```

- [ ] **Step 2: Add search index to ConferenceStore**

Add to `ConferenceNav/Services/ConferenceStore.swift`, after `loadSessions()` in `init()`:

Add these lines at the end of `init()`:

```swift
searchIndex.build(from: sessions)
```

And add the property:

```swift
var searchIndex = SearchIndex()
```

And a search method:

```swift
func search(_ query: String) -> [Session] {
    let ids = searchIndex.search(query)
    let idSet = Set(ids)
    return browseableSessions.filter { idSet.contains($0.id) }
}
```

- [ ] **Step 3: Create SearchView**

Create `ConferenceNav/Views/SearchView.swift`:

```swift
import SwiftUI

struct SearchView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var query = ""
    @State private var selectedDates: Set<String> = []
    @State private var selectedTypes: Set<SessionType> = []
    @State private var selectedVenues: Set<String> = []

    var results: [Session] {
        var sessions: [Session]
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            sessions = store.browseableSessions
        } else {
            sessions = store.search(query)
        }

        // Apply filters
        sessions = sessions.filter { session in
            (selectedDates.isEmpty || selectedDates.contains(session.date)) &&
            (selectedTypes.isEmpty || selectedTypes.contains(session.type)) &&
            (selectedVenues.isEmpty || selectedVenues.contains(session.venue))
        }

        return sessions.sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CNColors.textSecondary)
                    TextField("Search sessions, speakers, topics...", text: $query)
                        .font(CNFonts.body)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(CNColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(CNColors.surfaceSecondary(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Filter chips
                VStack(spacing: 4) {
                    FilterChips(
                        label: "Day",
                        options: store.dates,
                        selected: $selectedDates,
                        title: { date in
                            switch date {
                            case "2026-05-14": return "Thu"
                            case "2026-05-15": return "Fri"
                            case "2026-05-16": return "Sat"
                            default: return date
                            }
                        }
                    )
                    FilterChips(
                        label: "Type",
                        options: SessionType.filterableTypes,
                        selected: $selectedTypes,
                        title: \.rawValue
                    )
                    FilterChips(
                        label: "Room",
                        options: store.allVenues,
                        selected: $selectedVenues,
                        title: { $0 }
                    )
                }
                .padding(.vertical, 4)

                // Results
                if query.isEmpty && selectedDates.isEmpty && selectedTypes.isEmpty && selectedVenues.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(CNColors.textSecondary.opacity(0.5))
                        Text("Search sessions, speakers, topics...")
                            .font(CNFonts.body)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No matches")
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                        Text("Try different keywords or adjust filters")
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { session in
                                NavigationLink(value: session.id) {
                                    SessionCardView(session: session, showTime: true)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Search")
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build to verify**

Run: ⌘B
Expected: Compiles cleanly.

- [ ] **Step 5: Commit**

```bash
git add ConferenceNav/Services/SearchIndex.swift ConferenceNav/Views/SearchView.swift ConferenceNav/Services/ConferenceStore.swift
git commit -m "feat: add full-text SearchIndex and SearchView with filter chips"
```

---

### Task 10: My Picks View (Tab 3)

**Files:**
- Create: `ConferenceNav/Views/MyPicksView.swift`

- [ ] **Step 1: Create MyPicksView**

Create `ConferenceNav/Views/MyPicksView.swift`:

```swift
import SwiftUI

struct MyPicksView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    private let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
    private let dayLabels = [
        "2026-05-14": "Thursday, 14 May",
        "2026-05-15": "Friday, 15 May",
        "2026-05-16": "Saturday, 16 May",
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.myPickedSessions.isEmpty {
                    emptyState
                } else {
                    pickedList
                }
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("My Picks")
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(CNColors.gold(for: colorScheme).opacity(0.4))
            Text("No sessions picked yet")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            Text("Browse the Schedule and tap ★ to build your programme.")
                .font(CNFonts.body)
                .foregroundStyle(CNColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var pickedList: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Summary header
                HStack(spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        let count = store.pickCount(for: date)
                        let short = date == "2026-05-14" ? "Thu" : date == "2026-05-15" ? "Fri" : "Sat"
                        Text("\(short): \(count)")
                            .font(CNFonts.sans(13, weight: .medium))
                            .foregroundStyle(
                                count > 0
                                    ? CNColors.navy(for: colorScheme)
                                    : CNColors.textSecondary
                            )
                    }
                }
                .padding(.vertical, 8)

                // Day sections
                ForEach(dates, id: \.self) { date in
                    let daySessions = store.myPickedSessions.filter { $0.date == date }
                    if !daySessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayLabels[date] ?? date)
                                .font(CNFonts.title2)
                                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            ForEach(daySessions) { session in
                                NavigationLink(value: session.id) {
                                    SessionCardView(session: session, showTime: true)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: ⌘B → Expected: Compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/MyPicksView.swift
git commit -m "feat: add MyPicksView with day grouping, summary header, and empty state"
```

---

### Task 11: Mates View (Tab 4)

**Files:**
- Create: `ConferenceNav/Views/MatesView.swift`

- [ ] **Step 1: Create MatesView**

Create `ConferenceNav/Views/MatesView.swift`:

```swift
import SwiftUI

struct MatesView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    enum MateFilter: String, CaseIterable {
        case ben = "Ben's Picks"
        case ron = "Ron's Picks"
        case both = "Both"
    }

    @State private var filter: MateFilter = .ron

    private let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
    private let dayLabels = [
        "2026-05-14": "Thursday, 14 May",
        "2026-05-15": "Friday, 15 May",
        "2026-05-16": "Saturday, 16 May",
    ]

    private var defaultFilter: MateFilter {
        store.currentUser == .ben ? .ron : .ben
    }

    private var filteredSessions: [Session] {
        switch filter {
        case .ben:
            return store.currentUser == .ben
                ? store.myPickedSessions
                : store.matePickedSessions
        case .ron:
            return store.currentUser == .ron
                ? store.myPickedSessions
                : store.matePickedSessions
        case .both:
            return store.bothPickedSessions
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // User pills
                HStack(spacing: 8) {
                    ForEach(MateFilter.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(CNFonts.sans(13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    filter == option
                                        ? CNColors.navy(for: colorScheme)
                                        : CNColors.surfaceSecondary(for: colorScheme)
                                )
                                .foregroundStyle(
                                    filter == option
                                        ? .white
                                        : CNColors.textPrimary(for: colorScheme)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 12)

                if filteredSessions.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundStyle(CNColors.textSecondary.opacity(0.4))
                        Text(filter == .both ? "No sessions in common yet" : "No picks yet")
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(dates, id: \.self) { date in
                                let daySessions = filteredSessions.filter { $0.date == date }
                                if !daySessions.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(dayLabels[date] ?? date)
                                            .font(CNFonts.title2)
                                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                            .padding(.horizontal, 16)
                                            .padding(.top, 12)

                                        ForEach(daySessions) { session in
                                            NavigationLink(value: session.id) {
                                                SessionCardView(session: session, showTime: true)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Mates")
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
            .onAppear {
                filter = defaultFilter
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: ⌘B → Expected: Compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/MatesView.swift
git commit -m "feat: add MatesView with Ben/Ron/Both filter pills"
```

---

### Task 12: Session Detail View

**Files:**
- Modify: `ConferenceNav/Views/SessionDetailView.swift`

- [ ] **Step 1: Replace placeholder with full detail view**

Replace entire contents of `ConferenceNav/Views/SessionDetailView.swift`:

```swift
import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme
    @State private var showFullDescription = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    TypeBadge(type: session.type)

                    Text(session.title)
                        .font(CNFonts.largeTitle)
                        .foregroundStyle(CNColors.textPrimary(for: colorScheme))

                    // Time + Venue
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        Text("\(session.dayLabel) · \(session.startsAt)-\(session.endsAt)")
                            .font(CNFonts.time)
                        Text("·")
                        Image(systemName: "mappin")
                            .font(.system(size: 14))
                        Text(session.venue)
                            .font(CNFonts.sans(14, weight: .semibold))
                    }
                    .foregroundStyle(CNColors.teal(for: colorScheme))

                    // Pick + badges row
                    HStack(spacing: 12) {
                        PickButton(sessionId: session.id)
                        MateBadges(session: session)
                        Spacer()
                    }

                    // Conflict warning
                    if let conflict = store.conflictingSession(for: session),
                       store.isPicked(session.id) {
                        ConflictBanner(conflictingTitle: conflict.title)
                    }
                }
                .padding(.horizontal, 16)

                // Description
                if !session.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(CNFonts.sans(13, weight: .semibold))
                            .foregroundStyle(CNColors.textSecondary)
                            .textCase(.uppercase)

                        Text(session.description)
                            .font(CNFonts.body)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            .lineLimit(showFullDescription ? nil : 4)

                        if session.description.count > 200 {
                            Button {
                                withAnimation { showFullDescription.toggle() }
                            } label: {
                                Text(showFullDescription ? "Show less" : "Show more")
                                    .font(CNFonts.sans(13, weight: .medium))
                                    .foregroundStyle(CNColors.teal(for: colorScheme))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Presentations
                if !session.presentations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presentations (\(session.presentations.count))")
                            .font(CNFonts.sans(13, weight: .semibold))
                            .foregroundStyle(CNColors.textSecondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)

                        ForEach(session.presentations) { pres in
                            PresentationRow(presentation: pres)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(CNColors.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Presentation Row

struct PresentationRow: View {
    let presentation: Presentation
    @Environment(\.colorScheme) var colorScheme
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Time + title
            HStack(alignment: .top) {
                if !presentation.startsAt.isEmpty {
                    Text("\(presentation.startsAt)-\(presentation.endsAt)")
                        .font(CNFonts.timeSmall)
                        .foregroundStyle(CNColors.textSecondary)
                        .frame(width: 80, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(CNFonts.sans(14, weight: .semibold))
                        .foregroundStyle(CNColors.textPrimary(for: colorScheme))

                    if !presentation.presenter.isEmpty {
                        Text(presentation.presenter)
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.teal(for: colorScheme))
                    }

                    // Expandable authors
                    if presentation.authors.count > 1 {
                        Button {
                            withAnimation { expanded.toggle() }
                        } label: {
                            Text(expanded ? "Hide authors" : "\(presentation.authors.count) authors")
                                .font(CNFonts.sans(11, weight: .medium))
                                .foregroundStyle(CNColors.textSecondary)
                        }

                        if expanded {
                            ForEach(presentation.authors, id: \.name) { author in
                                HStack(spacing: 4) {
                                    Text(author.name)
                                        .font(CNFonts.small)
                                        .foregroundStyle(
                                            author.presenting
                                                ? CNColors.teal(for: colorScheme)
                                                : CNColors.textSecondary
                                        )
                                    if !author.organisation.isEmpty {
                                        Text("— \(author.organisation)")
                                            .font(CNFonts.small)
                                            .foregroundStyle(CNColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(CNColors.surfaceSecondary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: ⌘B → Expected: Compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SessionDetailView.swift
git commit -m "feat: add full SessionDetailView with description, presentations, and conflict warnings"
```

---

### Task 13: Main Tab View & User Picker

**Files:**
- Create: `ConferenceNav/Views/MainTabView.swift`
- Create: `ConferenceNav/Views/UserPickerView.swift`
- Modify: `ConferenceNav/ConferenceNavApp.swift`

- [ ] **Step 1: Create MainTabView**

Create `ConferenceNav/Views/MainTabView.swift`:

```swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            MyPicksView()
                .tabItem {
                    Label("My Picks", systemImage: "star.fill")
                }

            MatesView()
                .tabItem {
                    Label("Mates", systemImage: "person.2.fill")
                }
        }
        .tint(CNColors.navy(for: colorScheme))
    }
}
```

- [ ] **Step 2: Create UserPickerView**

Create `ConferenceNav/Views/UserPickerView.swift`:

```swift
import SwiftUI

struct UserPickerView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme
    var onSelect: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("EAPC 2026")
                    .font(CNFonts.sans(14, weight: .semibold))
                    .foregroundStyle(CNColors.textSecondary)
                    .tracking(3)
                Text("Conference\nNavigator")
                    .font(CNFonts.serif(36))
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            Text("Who are you?")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textSecondary)

            HStack(spacing: 20) {
                userButton(.ben)
                userButton(.ron)
            }

            Spacer()

            Text("Programme data as of \(store.lastUpdated)")
                .font(CNFonts.small)
                .foregroundStyle(CNColors.textSecondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(CNColors.background(for: colorScheme))
    }

    private func userButton(_ user: UserProfile) -> some View {
        Button {
            store.switchUser(to: user)
            UserDefaults.standard.set(user.id, forKey: "conferenceNavUser")
            onSelect()
        } label: {
            VStack(spacing: 8) {
                Text(user.badge)
                    .font(CNFonts.serif(32))
                    .frame(width: 72, height: 72)
                    .background(CNColors.navy(for: colorScheme))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                Text(user.displayName)
                    .font(CNFonts.headline)
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            }
        }
    }
}
```

- [ ] **Step 3: Update app entry point**

Replace `ConferenceNav/ConferenceNavApp.swift`:

```swift
import SwiftUI

@main
struct ConferenceNavApp: App {
    @State private var store = ConferenceStore()
    @AppStorage("conferenceNavUser") private var savedUserId: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if savedUserId != nil {
                    MainTabView()
                } else {
                    UserPickerView {
                        // onSelect callback — savedUserId gets set in UserPickerView
                    }
                }
            }
            .environment(store)
            .onAppear {
                if let id = savedUserId {
                    let user: UserProfile = id == "ron" ? .ron : .ben
                    store.switchUser(to: user)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build and run**

Run: ⌘R
Expected: App launches showing "Who are you?" picker with Ben and Ron circles. Tapping one navigates to the four-tab view with a working Schedule.

- [ ] **Step 5: Commit**

```bash
git add ConferenceNav/Views/MainTabView.swift ConferenceNav/Views/UserPickerView.swift ConferenceNav/ConferenceNavApp.swift
git commit -m "feat: add MainTabView, UserPickerView, and wire up app entry point"
```

---

### Task 14: Supabase Pick Sync

**Files:**
- Create: `ConferenceNav/Services/PicksSyncService.swift`
- Modify: `ConferenceNav/Services/ConferenceStore.swift`

- [ ] **Step 1: Create Supabase SQL table**

Run this SQL in the Supabase SQL Editor (https://supabase.com/dashboard):

```sql
CREATE TABLE conference_picks (
    id          SERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    session_id  INTEGER NOT NULL,
    picked_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, session_id)
);

ALTER TABLE conference_picks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow anon all on conference_picks" ON conference_picks
    FOR ALL USING (true) WITH CHECK (true);
```

- [ ] **Step 2: Create PicksSyncService**

Create `ConferenceNav/Services/PicksSyncService.swift`:

```swift
import Foundation

actor PicksSyncService {
    private let baseURL = "https://dyxupzbyssvcxjppipnl.supabase.co/rest/v1"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5eHVwemJ5c3N2Y3hqcHBpcG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjc0MTksImV4cCI6MjA4NDUwMzQxOX0._pmFY2kmyUYLauX-BQeELbWziJ4nuXIaxOM5YsUYsBI"

    struct PickRow: Codable {
        let userId: String
        let sessionId: Int

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case sessionId = "session_id"
        }
    }

    // MARK: - Fetch picks for a user

    func fetchPicks(userId: String) async throws -> Set<Int> {
        let url = URL(string: "\(baseURL)/conference_picks?user_id=eq.\(userId)&select=session_id")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct Row: Decodable { let session_id: Int }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        return Set(rows.map(\.session_id))
    }

    // MARK: - Add a pick

    func addPick(userId: String, sessionId: Int) async throws {
        let url = URL(string: "\(baseURL)/conference_picks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body = PickRow(userId: userId, sessionId: sessionId)
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Remove a pick

    func removePick(userId: String, sessionId: Int) async throws {
        let url = URL(string: "\(baseURL)/conference_picks?user_id=eq.\(userId)&session_id=eq.\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
```

- [ ] **Step 3: Wire sync into ConferenceStore**

Add to `ConferenceNav/Services/ConferenceStore.swift`. Add the sync service property:

```swift
private let syncService = PicksSyncService()
```

Add a sync method:

```swift
// MARK: - Supabase Sync

func syncPicks() async {
    do {
        // Fetch both users' picks
        let myRemotePicks = try await syncService.fetchPicks(userId: currentUser.id)
        let mateRemotePicks = try await syncService.fetchPicks(userId: currentUser.mate.id)

        // Merge remote into local (remote wins for mate, union for self)
        await MainActor.run {
            // For own picks: union of local and remote
            let merged = myPicks.union(myRemotePicks)
            if merged != myPicks {
                myPicks = merged
            }
            matePicks = mateRemotePicks
        }

        // Push any local-only picks to remote
        let localOnly = myPicks.subtracting(myRemotePicks)
        for sessionId in localOnly {
            try await syncService.addPick(userId: currentUser.id, sessionId: sessionId)
        }
    } catch {
        print("Pick sync failed: \(error.localizedDescription)")
    }
}

func syncTogglePick(_ sessionId: Int) {
    let wasAdded = myPicks.contains(sessionId)
    // togglePick already called, so wasAdded means it was just removed
    Task {
        do {
            if wasAdded {
                try await syncService.removePick(userId: currentUser.id, sessionId: sessionId)
            } else {
                try await syncService.addPick(userId: currentUser.id, sessionId: sessionId)
            }
        } catch {
            print("Failed to sync pick: \(error.localizedDescription)")
        }
    }
}
```

Update `togglePick` to also trigger sync:

```swift
func togglePick(_ sessionId: Int) {
    let removing = myPicks.contains(sessionId)
    if removing {
        myPicks.remove(sessionId)
    } else {
        myPicks.insert(sessionId)
    }
    // Background sync
    Task {
        do {
            if removing {
                try await syncService.removePick(userId: currentUser.id, sessionId: sessionId)
            } else {
                try await syncService.addPick(userId: currentUser.id, sessionId: sessionId)
            }
        } catch {
            print("Failed to sync pick: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 4: Add sync on app launch**

Update `ConferenceNavApp.swift` to sync on appear. Add `.task` modifier to the Group:

```swift
Group {
    if savedUserId != nil {
        MainTabView()
    } else {
        UserPickerView {
            // onSelect
        }
    }
}
.environment(store)
.onAppear {
    if let id = savedUserId {
        let user: UserProfile = id == "ron" ? .ron : .ben
        store.switchUser(to: user)
    }
}
.task {
    if savedUserId != nil {
        await store.syncPicks()
    }
}
```

- [ ] **Step 5: Add pull-to-refresh on MatesView**

Add `.refreshable` modifier to the ScrollView in `MatesView.swift`:

```swift
ScrollView {
    // ... existing content ...
}
.refreshable {
    await store.syncPicks()
}
```

- [ ] **Step 6: Build and run**

Run: ⌘R
Expected: App compiles and runs. Picks sync to Supabase. Pull-to-refresh on Mates tab fetches latest picks.

- [ ] **Step 7: Commit**

```bash
git add ConferenceNav/Services/PicksSyncService.swift ConferenceNav/Services/ConferenceStore.swift ConferenceNav/ConferenceNavApp.swift ConferenceNav/Views/MatesView.swift
git commit -m "feat: add Supabase pick sync with optimistic UI and pull-to-refresh"
```

---

### Task 15: Polish & Final Integration

**Files:**
- Modify: Various views for refinements

- [ ] **Step 1: Add "data as of" to Schedule header**

In `ScheduleView.swift`, add a toolbar item to the NavigationStack:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Text("Data: \(store.lastUpdated)")
            .font(CNFonts.small)
            .foregroundStyle(CNColors.textSecondary)
    }
}
```

- [ ] **Step 2: Add pull-to-refresh to MyPicksView**

Add `.refreshable` to the ScrollView in `MyPicksView.swift`:

```swift
ScrollView {
    // ... existing content ...
}
.refreshable {
    await store.syncPicks()
}
```

- [ ] **Step 3: Full integration test**

Run the app and verify:
1. First launch shows "Who are you?" → tap Ben → lands on Schedule tab
2. Schedule: Day picker switches days, filter chips filter sessions, time slot headers show parallel counts
3. Tap a session card → Session Detail shows title, time, venue, type, description, presentations
4. Tap star on card → gold star appears, session shows in My Picks tab
5. Pick two overlapping sessions → amber conflict banner appears on both
6. Search tab: type "pain" → shows Pain Management sessions. Type "Murray" → shows keynote
7. Filter chips in Search work (day + type + venue)
8. My Picks tab: shows picked sessions grouped by day with summary counts
9. Mates tab: shows Ben/Ron/Both pills. Defaults to mate's picks.
10. Pull-to-refresh on Mates tab syncs from Supabase

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: polish ConferenceNav with data stamp, pull-to-refresh, and integration verification"
```

- [ ] **Step 5: Push**

```bash
git push
```
