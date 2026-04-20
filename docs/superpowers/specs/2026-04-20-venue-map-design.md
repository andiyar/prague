# Venue Map — Design Spec

**Date:** 2026-04-20
**Status:** Approved
**Target:** ConferenceNav (EAPragueC 2026) — V5

## Purpose

Give Ben and Ron a fast, offline way to answer "which room is this session in, and where is that in the building?" at the O2 Universum, without having to decipher unfamiliar room codes (C2, D7, Hall A...) on the fly.

The venue is non-trivial: 11 rooms relevant to the programme, split across Floor 0/1 (Hall A), Floor 3 (C1–3, D3–9), and misc. areas (Printed Posters Hall, Refreshment & lunch area).

## Non-goals

- Indoor wayfinding with GPS
- Walking directions between rooms
- Matterport 3D tour integration
- Custom SVG floor plans (we use the O2 Universum JPGs as-is)

## User Flows

### Primary — "Where's my next session?"
1. User opens a session detail view.
2. Sees a new map thumbnail card showing the floor, room code, and a pulsing pin at the room.
3. Taps the thumbnail → full `VenueMapView` opens, focused on that floor and room with the pin pulsing.
4. Pinch/pan to explore; floor switcher at bottom flips between floors without backing out.

### Secondary — "Browse the venue"
5. Extras tab → new "Venue Map" row.
6. Opens `VenueMapView` defaulting to the floor of the user's next upcoming picked session (or Floor 3 if none picked).

### Tertiary — "What's my day look like?"
7. From `VenueMapView`, toggle "My Day" button in header.
8. Numbered pins (1, 2, 3...) drop for each of today's picks in chronological order, on the current floor.
9. Tapping a numbered pin shows a small popover: session title, time, type.
10. If picks span multiple floors, a floor-switcher badge shows e.g. "Floor 3 (2 picks) · Floor 0 (1 pick)".
11. Colliding pins (same room, back-to-back sessions) merge into a single pin labelled e.g. "1-2"; popover lists both.

## Data Model

Static Swift catalog — no Supabase tables, no fetch. Single source of truth in `ConferenceNav/Models/VenueMap.swift`.

```swift
enum VenueFloor: String, CaseIterable {
    case floor0, floor1, floor2, floor3, meetingHub

    var imageName: String        // Asset catalog name, e.g. "floor-3"
    var displayName: String      // "Floor 3", "Meeting Hub"
    var sortOrder: Int           // for the floor switcher
}

struct VenueRoom {
    let code: String             // matches programme.json "venue" exactly
    let displayName: String      // prettier UI form, e.g. "Hall C2"
    let floor: VenueFloor
    let pinPosition: CGPoint     // normalised 0.0–1.0 of floor plan image
}

enum VenueMapCatalog {
    static let rooms: [String: VenueRoom] = [ ... ]   // keyed on programme.json venue string
    static func room(for venue: String) -> VenueRoom?
}
```

### Venues to catalog (11 total)

Exact strings from `programme.json`:

| Venue string | Floor | Notes |
|---|---|---|
| `Hall A` | Floor 0 or 1 (TBD during impl) | Main large hall |
| `C1` | Floor 3 | Hall C |
| `C2` | Floor 3 | Hall C |
| `C3` | Floor 3 | Hall C |
| `D3` | Floor 3 | Hall D |
| `D4` | Floor 3 | Hall D |
| `D7` | Floor 3 | Hall D |
| `D8` | Floor 3 | Hall D |
| `D9` | Floor 3 | Hall D |
| `Printed Posters Hall` | TBD — check brochure PDF | Fallback: omit if not found on plans |
| `Refreshment & lunch area` | TBD — check brochure PDF | Fallback: omit if not found on plans |

### Graceful fallback

If `VenueMapCatalog.room(for:)` returns `nil` (unknown venue string), the session-detail thumbnail is silently omitted. No error UI. Users never see something they can't use.

## File Layout

```
ConferenceNav/
├── Resources/
│   └── Floors/                       # NEW — bundled floor plans
│       ├── floor-0.jpg
│       ├── floor-1.jpg
│       ├── floor-2.jpg
│       ├── floor-3.jpg
│       └── meeting-hub.jpg
├── Models/
│   └── VenueMap.swift                # NEW — VenueFloor, VenueRoom, VenueMapCatalog
├── Services/
│   └── DebugClock.swift              # NEW — #if DEBUG, else Date()
└── Views/
    └── VenueMap/                     # NEW subfolder
        ├── VenueMapView.swift        # Full-screen zoomable plan + pin(s) + floor switcher
        ├── VenueMapThumbnail.swift   # Small card for SessionDetailView
        ├── VenueMapPin.swift         # Reusable pin (single / numbered) + pulse animation
        ├── MyDayOverlay.swift        # Numbered-pins overlay + popover
        └── VenueMapDebugView.swift   # #if DEBUG — date picker + crosshair toggle
```

### Modified files

- `SessionDetailView.swift` — inserts `VenueMapThumbnail(venue: session.venue)`. No-op for unknown venues.
- `ExtrasView.swift` — new "Venue Map" row → `VenueMapView(initialFloor:)`. In debug builds, additional "Venue Map Debug" row.
- `project.yml` — register `Resources/Floors/` and new view files; regenerate pbxproj via `xcodegen`.
- `Assets.xcassets` — register floor plans as image assets.

## UI Details

### `VenueMapThumbnail` (on SessionDetailView)
- ~140pt tall card, full width, 12pt corner radius matching existing cards.
- Content: cropped + zoomed floor plan around the room, pulsing pin at room label position.
- Header strip: `Hall C2 · Floor 3` (navy gradient, matching other card headers).
- Tap → push `VenueMapView(focus: .specificRoom(room))`.

### `VenueMapView` (full-screen)
- Navigation title: `Floor 3` (or whichever floor).
- Large zoomable + pannable image (native SwiftUI `MagnificationGesture` + `DragGesture`, no third-party libs).
- Pin overlay: positioned in normalised image coordinates, transforms with the same scale/offset as the image so it stays glued to the room label.
- Header trailing: "My Day" toggle.
- Footer: segmented floor switcher (Floor 0 / 1 / 2 / 3 / Meeting Hub).

### `VenueMapPin`
- Default state: gold (`ConferenceDesign.gold`) teardrop pin, ~28pt.
- Pulse: expanding circle, `.scaleEffect` + `.opacity` with `.repeatForever(autoreverses: false)`, 2s cycle.
- Numbered variant for My Day: same pin shape with a number badge in the centre.
- Tap action (numbered variant): show popover with session title, time, type.

### `MyDayOverlay`
- Reads today's picks via `ConferenceStore`.
- Filters by `DebugClock.shared.currentDay` (`.may14` / `.may15` / `.may16`).
- Sorts chronologically, assigns numbers 1..N.
- Merges pins at the same venue into `"N-M"` labels.
- Renders numbered pins only on the currently-displayed floor; other floors' pick counts shown as subtle badges on the floor switcher.

### Colour palette (reuse existing)
- Pin default: `ConferenceDesign.gold` (`#C9A227` light / `#E0B840` dark)
- Pin selected: `ConferenceDesign.teal`
- Header gradient: existing navy card gradient
- No new colours introduced.

## Debug Mode (`#if DEBUG` only)

New "Venue Map Debug" row in the Extras tab opens a panel with two tools:

### 1. Simulated date picker
- Segmented picker with four options: Real today (default) / May 14 / May 15 / May 16.
- `DebugClock.shared.simulatedDate` drives the My Day overlay's "today".
- Debug builds only. In release, `DebugClock` returns `Date()` unconditionally and has no UI.

### 2. Pin coordinate inspector
- Toggle "Show pin crosshairs". When on, every floor plan view renders a `+` crosshair and room code label at each catalogued pin.
- Purpose: scan all 11 pins and confirm placements look right before shipping.
- This is the primary authoring tool for the coordinate catalog.

### Non-goals for debug mode
- Time-of-day simulation (not needed — no "starts in X min" copy anywhere)
- Forced session navigation
- Any debug surface in release builds

## Technical Details

### Pin coordinate authoring
- Done once by the implementer: open each floor plan JPG, locate the room label, estimate normalised (x, y) where the label sits, write it into `VenueMapCatalog`.
- Verify with the debug crosshair toggle.
- 11 venues × one `CGPoint` each = afternoon's work.

### Pinch-zoom-pan math
- Single `GeometryReader` wrapping image + pin overlay in a `ZStack`.
- Same `.scaleEffect` + `.offset` modifiers applied to both layers.
- Pin's `CGPoint` multiplied by displayed image size.
- Well-trodden SwiftUI pattern, no third-party deps.

### `DebugClock` service
```swift
final class DebugClock: ObservableObject {
    static let shared = DebugClock()

    #if DEBUG
    @Published var simulatedDate: Date?
    var now: Date { simulatedDate ?? Date() }
    #else
    var now: Date { Date() }
    #endif
}
```
Views that need "now" (only `MyDayOverlay` in this spec) read `DebugClock.shared.now`.

### Image assets
- Floor plan JPGs stored as image sets in `Assets.xcassets`.
- Single-resolution (no @2x/@3x needed — JPEGs are ~1050px wide, acceptable at retina scales given pinch-zoom).
- Total bundle cost: ~1.7 MB for all 5 floors.

## Testing Strategy

- **Manual visual inspection** — debug crosshair overlay, cycle through all 11 venues, confirm every pin sits on the right room. Do before committing coordinate catalog.
- **Unit tests** in a new `VenueMapTests.swift`:
  - `VenueMapCatalog.room(for:)` returns correct room for each of the 11 programme venues
  - Returns `nil` for unknown input
  - `MyDayOverlay` sorting: picks are chronological, numbered 1..N
  - `MyDayOverlay` collision merging: two picks in same room collapse to single "N-M" pin
- **No UI snapshot tests** — app has none, not starting here.

## Effort Estimate

- Pin coordinate authoring: 0.5 day
- `VenueMap.swift` + `DebugClock.swift` + tests: 0.5 day
- `VenueMapView` + zoom/pan + pin rendering: 1 day
- `VenueMapThumbnail` + SessionDetailView integration: 0.5 day
- `MyDayOverlay` + popover + collision merging: 0.5 day
- Debug panel + Extras integration: 0.5 day
- Polish, bug-fix buffer: 0.5 day

**Total: ~4 days** of implementation work.

## Open Questions

- Which floor is `Hall A` actually on — Floor 0 or Floor 1? The brochure lists it across both. Resolve during implementation by inspecting the plans.
- Where do `Printed Posters Hall` and `Refreshment & lunch area` sit? Check the brochure PDF. If not locatable, accept the graceful fallback (no thumbnail for those sessions).

## Acceptance Criteria

- [ ] Session detail view shows a map thumbnail for all 9 unambiguous venues (Hall A, C1–3, D3–9)
- [ ] Tapping the thumbnail opens `VenueMapView` with the pin on the correct room
- [ ] Pinch, pan, and floor switcher all work smoothly
- [ ] Extras → Venue Map opens the view defaulted to a sensible floor
- [ ] My Day overlay shows today's picks, numbered in chronological order
- [ ] Debug date picker changes which day's picks My Day shows
- [ ] Debug crosshair overlay marks every catalogued pin correctly
- [ ] Release build has zero debug UI visible
- [ ] Unknown venues silently omit the thumbnail — no crashes, no error states
