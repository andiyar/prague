# Where's Ben? - iOS Apps

Two native iOS apps for tracking Ben's EAPC Prague conference trip (May 12-18, 2026), plus a standalone conference navigator app.

## Apps

| App | Target | Purpose |
|-----|--------|---------|
| **WheresBen** | Wife's iPhone 17 (iOS 26) | Dashboard: location, flights, trip info, kids mode |
| **CaptainsLog** | Ben's iPhone | Quick status updater with GPS |
| **EAPragueC 2026** | Ben + Ron's iPhones | Conference programme browser, search, personal picks |

## Tech Stack

- **SwiftUI** (iOS 26)
- **Supabase** (existing backend from web project)
- **Apple Maps** (MapKit)
- **Push Notifications** (APNs via Supabase Edge Functions)

## Design Document

Full design spec: `docs/plans/2025-01-28-app-design.md`

## Supabase Credentials

```
SUPABASE_URL=https://dyxupzbyssvcxjppipnl.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5eHVwemJ5c3N2Y3hqcHBpcG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjc0MTksImV4cCI6MjA4NDUwMzQxOX0._pmFY2kmyUYLauX-BQeELbWziJ4nuXIaxOM5YsUYsBI
```

## Existing Database Tables

Already populated from web project:

- `trip_segments` - Pre-planned schedule (all UTC times)
- `status_override` - Manual status updates
- `config` - Trip details, contacts

## New Tables Needed

```sql
-- Device tokens for push notifications
CREATE TABLE push_tokens (
    device_id    TEXT PRIMARY KEY,
    token        TEXT NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Track sent notifications to avoid duplicates
CREATE TABLE sent_notifications (
    id           SERIAL PRIMARY KEY,
    trigger_type TEXT NOT NULL,
    trigger_id   TEXT NOT NULL,
    sent_at      TIMESTAMPTZ DEFAULT NOW()
);

-- RLS policies
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE sent_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon insert on push_tokens" ON push_tokens FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon select on push_tokens" ON push_tokens FOR SELECT USING (true);
CREATE POLICY "Allow anon insert on sent_notifications" ON sent_notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon select on sent_notifications" ON sent_notifications FOR SELECT USING (true);
```

## Design Language

### Family View (Cozy)
- Background: `#FAF7F2` (soft cream)
- Accent: `#C4846C` (muted terracotta)
- Success: `#8FA98F` (soft sage)
- Text: `#3D3D3D` (warm charcoal)
- Font: SF Pro Rounded
- Cards: 16-20pt corners, subtle shadows

### Kids View (Playful)
- Sky gradient background
- Chunky rounded text
- Bouncy animations
- Clouds, sparkles, confetti

## Key Features

### Where's Ben?
- **Tab 1 (Where's Ben?):** Status card, Apple Maps, quick info, next up
- **Tab 2 (Flights):** Collapsible flight cards, active flight glows, tap → FlightRadar WebView
- **Tab 3 (Trip Info):** Schedule, hotel, WhatsApp contact, emergency numbers
- **Tab 4 (Kids):** Full-screen playful view, big emoji, sleeps countdown

### Captain's Log
- Quick status grid (8 presets + custom)
- Auto GPS capture
- Send confirmation
- Recent history

### Push Notifications
- Captain's Log posts → immediate push
- Flight departures → 30 mins before
- Flight landings → 30 mins before
- Ben's presentation → 1 hour before

### Test Mode
- Debug button in header
- Tap date/time to scrub through trip timeline
- Test all states before May

## Project Structure

```
WheresBen/
├── WheresBen/           # Wife's app (Xcode target in WheresBen.xcodeproj)
├── CaptainsLog/         # Ben's app (Xcode target in WheresBen.xcodeproj)
├── Shared/              # Shared models & services (WheresBen/CaptainsLog)
├── ConferenceNav/       # Standalone conference app (own .xcodeproj)
│   ├── ConferenceNav.xcodeproj   # Generated via xcodegen from project.yml
│   ├── ConferenceNavApp.swift    # App entry point with splash screen
│   ├── Models/                   # Session, Presentation, Author, UserProfile
│   ├── Services/                 # ConferenceStore, SearchIndex, PicksSyncService
│   ├── Design/                   # ConferenceDesign (colours, fonts, card style)
│   ├── Views/                    # All SwiftUI views
│   │   ├── Components/           # DayPicker, TypeBadge, MateBadges, etc.
│   │   ├── ScheduleView.swift    # Tab 1: day-by-day timeline
│   │   ├── SearchView.swift      # Tab 2: full-text search + filters
│   │   ├── MyPicksView.swift     # Tab 3: personal programme
│   │   ├── MatesView.swift       # Tab 4: mate's picks
│   │   ├── SessionDetailView.swift
│   │   ├── SplashScreen.swift    # "Your Conference Czechlist"
│   │   └── UserPickerView.swift  # First-launch Ben/Ron picker
│   ├── Resources/programme.json  # 98 sessions, 1289 presentations
│   └── project.yml               # xcodegen spec (run: cd ConferenceNav && xcodegen)
├── data/eapc/           # Raw extracted programme data + scripts
├── sql/                 # Supabase migration SQL files
├── docs/                # Design documents and plans
└── CLAUDE.md            # This file
```

## Trip Details

### Passenger
Dr Benjamin Wayne Thomas

### Flights (Cathay Pacific / British Airways, Business Class, B777/A320)
| Flight | Route | Depart | Arrive |
|--------|-------|--------|--------|
| CX100 | SYD→HKG | Tue 12 May 14:05 | Tue 12 May 21:30 |
| CX255 | HKG→LHR | Tue 12 May 23:15 | Wed 13 May 06:20 |
| BA852 | LHR→PRG | Wed 13 May 08:35 | Wed 13 May 11:30 |
| BA853 | PRG→LHR | Sat 16 May 14:05 | Sat 16 May 15:15 |
| CX250 | LHR→HKG | Sat 16 May 18:20 | Sun 17 May 14:10 |
| CX181 | HKG→SYD | Mon 18 May 00:45 | Mon 18 May 11:45 |

### Hotel
STAGES HOTEL Prague
Ceskomoravska 19a, Prague, CZ-19000
Check-in: Wed 13 May 15:00
Check-out: Sat 16 May 12:00

### Conference
EAPC World Congress 2026
O2 Arena Prague
May 14-16, 2026
Ben presenting (time TBD)

## Location Coordinates

| Location | Lat | Lng |
|----------|-----|-----|
| Sydney Airport | -33.9461 | 151.1772 |
| Hong Kong Airport | 22.3080 | 113.9185 |
| London Heathrow | 51.4700 | -0.4543 |
| Prague Airport | 50.1008 | 14.2600 |
| STAGES Hotel | 50.1097 | 14.4990 |
| O2 Arena Prague | 50.1047 | 14.4923 |
| Wollongong (home) | -34.4278 | 150.8931 |

## Status Options (Captain's Log)

| Icon | Status | Kids Text |
|------|--------|-----------|
| ✈️ | Taking off | Daddy's on the plane! |
| 🛬 | Just landed | Daddy just landed! |
| 🏨 | At hotel | Daddy's at the hotel |
| 📍 | At conference | Daddy's at the conference |
| 🍽️ | Getting food | Daddy's having dinner |
| 😴 | Going to sleep | Daddy's sleeping |
| ☕ | Awake now | Daddy's awake! |
| 🏠 | Heading home | Daddy's coming home! |
| 💬 | [Custom] | [Custom] |

## Push Notifications Setup

### 1. Run the SQL
Run `sql/push_notifications.sql` in Supabase SQL Editor to create the push tables.

### 2. Enable Push in Xcode
1. Select the WheresBen target
2. Go to Signing & Capabilities
3. Add "Push Notifications" capability
4. Add "Background Modes" → check "Remote notifications"

### 3. APNs Key (for production)
1. Go to Apple Developer Portal → Certificates, Identifiers & Profiles
2. Create a new Key → enable Apple Push Notifications service (APNs)
3. Download the .p8 file
4. Note the Key ID and Team ID

### 4. Deploy Edge Function (optional - for server-sent pushes)
```bash
cd ~/Developer/WheresBen
supabase functions deploy send-notification
```

### Current Implementation
- **Local notifications**: Scheduled from trip data on app launch (flight departures/landings)
- **Test button**: In debug mode, "Send Test Notification" button
- **Token registration**: Device tokens saved to Supabase `push_tokens` table

### Future: Server-sent pushes
When you post from Captain's Log, a Supabase webhook could trigger the Edge Function
to send a push to all registered devices. Requires APNs setup.

## Assets to Customize

### App Icons (1024x1024 PNG)
- `WheresBen/Assets.xcassets/AppIcon.appiconset/` - Pin/map, plane with heart, or "Dad" illustration
- `CaptainsLog/Assets.xcassets/AppIcon.appiconset/` - Ship's wheel, compass, captain's hat

### Colors (in Shared/Design/DesignSystem.swift)
- `cozyBackground`: #FAF7F2 (cream)
- `cozyAccent`: #C4846C (terracotta)
- `cozySage`: #8FA98F (sage)
- Kids palette: sky blue, sun yellow, purple, pink

### Status Icons (optional)
Currently using emoji. Can swap for custom illustrations in future.

---

## EAPragueC 2026 (ConferenceNav)

### Status: V2 In Progress (April 2026)

Standalone SwiftUI app for navigating the EAPC 2026 conference programme.
Display name: "EAPragueC 2026". Tagline: "Your Conference Czechlist".

### What's Built (V1)
- Browse 90 browseable sessions (98 total minus tea/lunch breaks) across 3 days
- Full-text search across session titles, presentations, speakers, organisations
- Search drills into detail view (shows only matching presentations, not all 265 posters)
- Filter chips: day, session type (Keynote/Oral/Panel/Poster/General/Meeting), room
- Pick/unpick sessions with gold star (optimistic UI)
- Conflict detection for overlapping picked sessions (amber warning)
- B/R badges showing Ben's and Ron's picks on every card
- My Picks tab with Mine/Ben/Ron/Both filter pills (merged Mates)
- Supabase sync for picks between two users
- Offline-capable (bundled JSON, UserDefaults pick cache)
- Light/dark mode with custom palette (navy/gold/teal)
- Splash screen with 3.5s display + 0.5s fade
- User identity picker on first launch (Ben or Ron)
- Extras tab: People directory, Session Notes, Export

### What's Built (V2 — April 2026)
- **Session Notes**: Per-session Markdown notes with YAML front matter
- **Markdown Preview**: In-app rendered preview via MarkdownUI (custom conference theme with navy headings, teal links)
- **Edit/Preview Toggle**: Write in monospaced TextEditor, preview rendered Markdown
- **Photo Capture**: Camera + photo library, photos saved alongside notes
- **Photo Strip**: Horizontal thumbnail strip in editor with delete buttons
- **Notes List**: Browse all notes from Extras tab, swipe-to-delete
- **Notes Button**: Teal note icon on session detail view (dot indicator when note exists)
- **Conference Report Export**: Combined Markdown report from picks + notes via share sheet
- **All Notes Export**: Export all session notes as single Markdown file
- **iCloud Drive Sync**: Notes stored in iCloud Drive Documents (falls back to local)
- **People Directory**: Local contact manager with add/edit/search/delete
- **People Export**: Export contacts as Markdown or CSV
- **Extras Tab**: People, Session Notes, Export (replaced old Mates tab)

### Supabase Table
```sql
-- Run sql/conference_picks.sql in Supabase SQL Editor
CREATE TABLE conference_picks (
    id          SERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,       -- 'ben' or 'ron'
    session_id  INTEGER NOT NULL,
    picked_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, session_id)
);
```

### Design Language
- Background: `#FAFAF7` (warm white) / `#0D0D1A` (dark)
- Navy: `#002664` / `#4A7FD4` — primary brand, active tabs
- Gold: `#C9A227` / `#E0B840` — picked stars, poster badges
- Teal: `#1B6B7D` / `#3DBAD4` — links, presenter names
- Red: `#D7153A` / `#FF4D6A` — keynote badges, Ron's badge
- Typography: New York (serif headlines), SF Pro (body), SF Mono (times)
- Cards: 12pt corners, coloured left border by session type

### Xcode Project
- Standalone project at `ConferenceNav/ConferenceNav.xcodeproj`
- Generated via xcodegen: `cd ConferenceNav && xcodegen generate`
- iOS 17.0+, SwiftUI, no external dependencies
- Bundle ID: `com.wheresBen.ConferenceNav`

### App Icon
- TODO: Finalising icon (compass/Prague theme, navy + gold)
- Place 1024x1024 PNG at `ConferenceNav/Assets.xcassets/AppIcon.appiconset/`
- Update Contents.json with filename

### What's Built (V3 — April 2026)
- **Push notifications**: Local reminders 15 min before picked sessions (excludes posters), deep link to session on tap

### What's Built (V5 — April 2026)
- **Venue Map**: 5 O2 Universum floor plans bundled (~1.7 MB) as Asset Catalog images. Map thumbnail on every session detail with pulsing pin → opens full-screen `VenueMapView`. Pinch-zoom (1×–5×), pan (clamped to image edges), double-tap to reset. Floor switcher (Floor 0/1/2/3/Meeting Hub) at the bottom of the map. Calendar-icon toolbar toggle swaps the single-pin focus for a "My Day" numbered overlay (today's picks in chronological order, merging back-to-back same-room sessions into "1-2" labels). Tapping a numbered pin shows a sheet with the session(s). DEBUG-only date picker (Thu 14 / Fri 15 / Sat 16 May) in Extras → "Venue Map Debug" so My Day can be validated pre-conference. DEBUG-only crosshair toggle in the map toolbar marks every catalogued pin position. Sessions with venues not in the catalog (e.g. "Printed Posters Hall", "Refreshment & lunch area" — neither visible on the bundled plans) silently omit the thumbnail.

### V4 Roadmap
- **Programme update**: Fetch updated JSON from URL without app rebuild
- **Programme data refresh**: If Exordo data changes before the conference

### Key Files to Know
| File | What it does |
|------|-------------|
| `ConferenceNav/project.yml` | xcodegen spec — edit this, not pbxproj directly |
| `ConferenceNav/Resources/programme.json` | Bundled conference data (copied from `data/eapc/programme_structured.json`) |
| `ConferenceNav/Services/ConferenceStore.swift` | Central state: sessions, picks, search, sync |
| `ConferenceNav/Services/PicksSyncService.swift` | Supabase REST calls for pick CRUD |
| `ConferenceNav/Services/NotificationService.swift` | Local push notifications for session reminders |
| `ConferenceNav/Design/ConferenceDesign.swift` | All colours, fonts, card modifier |
| `ConferenceNav/Design/MarkdownTheme.swift` | Custom MarkdownUI theme (conference palette) |
| `ConferenceNav/Models/SessionNote.swift` | Note model with YAML front matter serialisation |
| `ConferenceNav/Services/NotesStore.swift` | Notes CRUD, iCloud Drive file I/O, photo management |
| `ConferenceNav/Services/ContactStore.swift` | Local contact persistence per user |
| `ConferenceNav/Services/DebugClock.swift` | Abstracts 'today' so DEBUG builds can simulate conference dates |
| `ConferenceNav/Models/VenueMap.swift` | Static catalog: programme venue string → floor + normalised pin coords |
| `ConferenceNav/Views/NoteEditorView.swift` | Edit/preview Markdown editor with photo strip |
| `ConferenceNav/Views/NoteListView.swift` | Browse all session notes |
| `ConferenceNav/Views/ExtrasView.swift` | Extras tab: People, Notes, Export |
| `ConferenceNav/Views/ExportView.swift` | Export contacts, picks, notes, conference report |
| `ConferenceNav/Views/VenueMap/` | Full venue map feature: pin, view, thumbnail, MyDay overlay, debug |
| `docs/superpowers/specs/2026-04-12-conference-nav-design.md` | Full design spec |
| `docs/superpowers/plans/2026-04-12-conference-nav.md` | V1 implementation plan (complete) |
| `docs/superpowers/plans/2026-04-13-session-notes.md` | V2 session notes plan (complete) |
| `docs/superpowers/specs/2026-04-14-push-notifications-design.md` | V3 push notifications spec |
| `docs/superpowers/plans/2026-04-14-push-notifications.md` | V3 push notifications plan (complete) |
| `docs/superpowers/specs/2026-04-20-venue-map-design.md` | V5 venue map design spec |
| `docs/superpowers/plans/2026-04-20-venue-map.md` | V5 venue map implementation plan |
