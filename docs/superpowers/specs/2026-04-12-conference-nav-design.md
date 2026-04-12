# ConferenceNav — EAPC 2026 Conference Navigator

**Date:** 2026-04-12
**Status:** Design spec
**Users:** Ben Thomas, Ron (via TestFlight)
**Conference:** 20th World Congress of the European Association for Palliative Care, Prague, May 14-16 2026

## Purpose

A native iOS app for navigating the EAPC 2026 conference programme. Browse all 98 sessions and 1,289 presentations across 3 days, search by any keyword, build a personal programme, and see what your mate has picked.

Exordo (the conference platform) has no usable export, filtering, or personal schedule features. This app replaces it entirely.

## Architecture

### Platform & Target

- Native SwiftUI app, iOS 17.0+
- New Xcode target `ConferenceNav` in the existing `WheresBen.xcodeproj`
- Shares the `Shared/` directory for `SupabaseClient` and `DesignSystem` foundation (but has its own colour palette)

### Data Strategy

- **Programme data**: Bundled `programme.json` in the app bundle, decoded at launch into in-memory models
- **Last-updated stamp**: Displayed in the app header/settings so users know data currency
- **User picks**: Synced via Supabase `conference_picks` table (lightweight — just user_id + session_id + timestamp)
- **No authentication**: Two hardcoded user profiles ("Ben" and "Ron") selected on first launch. No login flow needed for two users.

### Supabase Table

```sql
CREATE TABLE conference_picks (
    id          SERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,       -- 'ben' or 'ron'
    session_id  INTEGER NOT NULL,    -- matches bundled session id
    picked_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, session_id)
);

ALTER TABLE conference_picks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow anon all on conference_picks" ON conference_picks
    FOR ALL USING (true) WITH CHECK (true);
```

## Navigation

Four-tab structure:

| Tab | Icon | Purpose |
|-----|------|---------|
| **Schedule** | calendar | Day-by-day timeline of all sessions, grouped by time slot |
| **Search** | magnifying glass | Full-text search + filter chips |
| **My Picks** | star | Personal programme — only your picked sessions, organised by day |
| **Mates** | people | Browse your mate's picks, filter by Ron / Ben / Both |

## Screens

### 1. Schedule (Tab 1)

The main browse view. Shows all sessions for a selected day.

**Layout:**
- **Day selector**: Three pill buttons at the top — Thu 14 May / Fri 15 May / Sat 16 May. Active day uses navy fill (light mode) or gold fill (dark mode).
- **Time slot groups**: Sessions grouped under time headers (e.g. "09:00 - 10:30 · 2 parallel sessions"). The header shows how many parallel sessions exist in that slot.
- **Session cards**: Each card shows:
  - Session title (bold, primary text)
  - Type badge (Keynote / Oral / Panel / Poster / General / Meeting) — small coloured pill
  - Venue + presentation count (secondary text, e.g. "Hall A · 6 talks")
  - Pick indicator: Filled gold star if you've picked it, outline if not
  - B/R badges: Small "B" badge (navy/blue) if Ben picked, "R" badge (red) if Ron picked. Both show if both picked.
  - Conflict indicator: If this session overlaps with another picked session, show an amber warning icon

**Interactions:**
- Tap a session card → push to Session Detail
- Tap the star on a card → toggle pick (optimistic UI, syncs to Supabase in background)
- Swipe between days (or tap pills)

### 2. Search (Tab 2)

Full-text search across all programme data.

**Layout:**
- **Search bar**: Top of screen, always visible. Searches across: session titles, session descriptions, presentation titles, speaker names (prefix + first + last), speaker organisations.
- **Filter chips** (below search bar): Horizontal scroll of toggleable chips:
  - Day: Thu / Fri / Sat
  - Type: Keynote / Oral / Panel / Poster / General / Meeting
  - Venue: Hall A / C1 / C2 / C3 / D3 / D4 / D7 / D8 / D9
- **Results list**: Same session card format as Schedule tab. Results update live as you type (local search, instant).
- **Empty state**: Before typing, show "Search sessions, speakers, topics..." prompt. If no results, show "No matches" with suggestion to adjust filters.

**Search implementation:**
- Build a search index at launch from bundled data
- Normalise text (lowercase, strip diacritics) for matching
- Search all fields simultaneously, rank by: title match > presentation title match > speaker match > description match > organisation match

### 3. My Picks (Tab 3)

Your personal conference programme.

**Layout:**
- **Day sections**: Thu / Fri / Sat, each showing only your picked sessions in chronological order
- **Session cards**: Same format as Schedule but with:
  - Time prominently displayed (this is your agenda now)
  - Conflict warnings: If two picked sessions overlap, both get an amber banner: "Conflicts with [other session title]"
- **Empty state**: "No sessions picked yet. Browse the Schedule and tap ★ to build your programme."
- **Summary header**: "Thu: 4 sessions · Fri: 6 sessions · Sat: 2 sessions"

**Conflict detection:**
- Compare `starts_at` and `ends_at` for all picked sessions within the same day
- Two sessions conflict if their time ranges overlap (start_a < end_b AND start_b < end_a)
- Show conflict on both conflicting sessions

### 4. Mates (Tab 4)

See what your conference buddy has picked.

**Layout:**
- **User pills**: Top section with two toggleable pills — "Ron's Picks" / "Ben's Picks" / "Both". Default shows the other person's picks (Ron sees Ben's, Ben sees Ron's).
- **"Both" filter**: Shows sessions that both users have picked — the overlap. Great for "let's go to this one together".
- **Session cards**: Same format, with B/R badges. When showing "Both", cards get a special "You're both going" indicator.
- **Day grouping**: Same as My Picks — grouped by day, chronological.

### 5. Session Detail (Push view)

Full detail view for a single session. Pushed from any session card tap.

**Layout:**
- **Header area:**
  - Type badge (coloured pill)
  - Session title (large, serif font — New York)
  - Time + Venue (prominent — "Thu 14 May · 11:15-12:45 · Hall A")
  - Pick toggle (large gold star button)
  - B/R badge row
  - Conflict warning (if applicable)
- **Chairs**: Not displayed (user doesn't care). Data is in the model but not rendered.
- **Description**: If the session has a description, show it in a collapsible section (collapsed by default if long)
- **Presentations list**: Each presentation shows:
  - Time (e.g. "11:15-11:35")
  - Title (bold)
  - Presenter name + organisation (secondary text)
  - Expandable: tap to see all authors with organisations and presenting flag

## Design Language

### Identity

The app has its own visual identity, inspired by Ben's EAPC poster. Academic but not boring — clean, confident, with warm metallics.

### Colour Palette

**Light Mode:**
| Token | Value | Usage |
|-------|-------|-------|
| `background` | #FAFAF7 (warm white) | Main background |
| `surface` | #FFFFFF | Cards, sheets |
| `surfaceSecondary` | #F5F3EE (cream) | Grouped backgrounds |
| `textPrimary` | #22272B (charcoal) | Headlines, body |
| `textSecondary` | #8C8C8C (mid grey) | Captions, metadata |
| `navy` | #002664 | Primary brand, nav highlights |
| `red` | #D7153A | Accents, type badges |
| `gold` | #C9A227 | Picked state, stars, premium indicators |
| `teal` | #1B6B7D | Secondary accent, links |
| `conflictAmber` | #E6940A | Conflict warnings |

**Dark Mode:**
| Token | Value | Usage |
|-------|-------|-------|
| `background` | #0D0D1A | Main background |
| `surface` | #1A1A2E | Cards, sheets |
| `surfaceSecondary` | #141425 | Grouped backgrounds |
| `textPrimary` | #FAFAF7 | Headlines, body |
| `textSecondary` | #8C8C8C | Captions, metadata |
| `navy` | #4A7FD4 | Primary brand (lightened for dark bg) |
| `red` | #FF4D6A | Accents (lightened) |
| `gold` | #E0B840 | Picked state, stars |
| `teal` | #3DBAD4 | Secondary accent |
| `conflictAmber` | #FFB340 | Conflict warnings |

### Typography

- **Headlines**: New York (SF Serif) — Bold, used for session titles in detail view and section headers
- **Body / UI**: SF Pro — Regular/Medium/Semibold, used for card text, labels, metadata
- **Monospace**: SF Mono — used for time displays to keep alignment clean

### Component Patterns

- **Session cards**: Rounded corners (12pt), subtle shadow (light mode) or border (dark mode). Left border accent colour based on session type.
- **Type badges**: Small pills with type-specific colours:
  - Keynote: Red
  - Oral: Navy
  - Panel: Teal
  - Poster: Gold
  - General: Mid grey
  - Meeting: Light grey
- **B/R badges**: Small rounded rectangles. "B" in navy/blue tint, "R" in red tint. Semi-transparent background with coloured text.
- **Day pills**: Horizontal selector, active pill filled, inactive pill outlined.
- **Pick star**: Outline when unpicked, filled gold when picked. Tap animation: brief scale pulse.
- **Conflict indicator**: Amber triangle-exclamation icon + amber text.

### Motion

- Tab switches: Standard iOS tab bar transition
- Card taps: Brief highlight, push navigation with standard iOS slide
- Pick toggle: Star scales up briefly (1.0 → 1.2 → 1.0, 200ms ease-out)
- Pull to refresh on Mates tab (re-fetches picks from Supabase)

## Data Models

### Bundled JSON Structure

The bundled `programme.json` uses snake_case keys (matching the Python extraction output). Use `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase` to map to Swift's camelCase properties.

```swift
struct Session: Codable, Identifiable {
    let id: Int
    let date: String              // "2026-05-14"
    let title: String
    let type: SessionType
    let venue: String
    let startsAt: String          // "09:00" (Prague time)
    let endsAt: String            // "10:30" (Prague time)
    let startsAtISO: String       // Full ISO for conflict detection
    let endsAtISO: String
    let description: String
    let chairs: [String]
    let presentationsCount: Int
    let presentations: [Presentation]
}

enum SessionType: String, Codable {
    case keynote = "Keynote"
    case oral = "Oral"
    case panel = "Panel"
    case poster = "Poster"
    case general = "General"
    case meeting = "Meeting"
}

struct Presentation: Codable, Identifiable {
    let id: Int
    let title: String
    let startsAt: String          // "09:00"
    let endsAt: String            // "09:30"
    let durationMins: Int
    let presenter: String
    let authors: [Author]
}

struct Author: Codable {
    let name: String
    let organisation: String
    let presenting: Bool
}
```

### App State

```swift
@Observable
class ConferenceStore {
    var sessions: [Session]                    // Loaded from bundle
    var myPicks: Set<Int>                      // Session IDs I've picked
    var matePicks: Set<Int>                    // Session IDs my mate picked
    var currentUser: UserProfile               // "ben" or "ron"
    var lastUpdated: String                    // Data currency date

    // Computed
    var myPickedSessions: [Session]            // Filtered + sorted
    var matePickedSessions: [Session]          // Filtered + sorted
    var conflicts: [(Session, Session)]        // Overlapping picked sessions
}

struct UserProfile {
    let id: String                             // "ben" or "ron"
    let displayName: String                    // "Ben" or "Ron"
    let badge: String                          // "B" or "R"
}
```

## User Identity

On first launch, a simple picker: "Who are you?" with two options — Ben or Ron. Stored in UserDefaults. Can be changed in a minimal settings view accessible from the Schedule tab header.

No authentication, no accounts. Just a local toggle that determines which user_id is sent to Supabase.

## Sync Strategy

- **Optimistic UI**: Tap star → immediately update local state → sync to Supabase in background
- **Pull to refresh**: On Mates tab and My Picks tab, pull down to re-fetch all picks from Supabase
- **Launch sync**: On app launch, fetch both users' picks from Supabase and merge with local state
- **Offline resilience**: Local picks stored in UserDefaults as backup. If Supabase is unreachable, app works fully offline with local picks. Syncs when connectivity returns.

## Project Structure

```
WheresBen/
├── ConferenceNav/                    # New Xcode target
│   ├── ConferenceNavApp.swift        # App entry point
│   ├── Views/
│   │   ├── ScheduleView.swift        # Tab 1: Day-by-day timeline
│   │   ├── SearchView.swift          # Tab 2: Full-text search
│   │   ├── MyPicksView.swift         # Tab 3: Personal programme
│   │   ├── MatesView.swift           # Tab 4: Mate's picks
│   │   ├── SessionDetailView.swift   # Push detail view
│   │   ├── SessionCardView.swift     # Reusable session card
│   │   └── Components/
│   │       ├── DayPicker.swift       # Thu/Fri/Sat pill selector
│   │       ├── TypeBadge.swift       # Session type pill
│   │       ├── MateBadges.swift      # B/R badge views
│   │       ├── PickButton.swift      # Gold star toggle
│   │       ├── ConflictBanner.swift  # Overlap warning
│   │       └── FilterChips.swift     # Scrollable filter pills
│   ├── Models/
│   │   ├── Session.swift             # Session + Presentation models
│   │   └── UserProfile.swift         # Ben/Ron identity
│   ├── Services/
│   │   ├── ConferenceStore.swift     # Main state + business logic
│   │   ├── SearchIndex.swift         # Full-text search engine
│   │   └── PicksSyncService.swift    # Supabase picks sync
│   ├── Design/
│   │   └── ConferenceDesign.swift    # Colour palette, typography tokens
│   ├── Resources/
│   │   └── programme.json            # Bundled conference data
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/       # App icon (TBD)
├── Shared/                           # Existing shared code
│   └── Services/
│       └── SupabaseClient.swift      # Reused for picks sync
└── ...
```

## Scope Boundaries

### V1 (This Build)

- Browse full programme by day
- Full-text search with filters
- Pick/unpick sessions
- See mate's picks with B/R badges
- Conflict detection for overlapping picks
- System-adaptive light/dark mode
- Offline-capable (bundled data, local picks cache)

### V2 (Post-Conference or if Time Permits)

- **Session notes**: Text notes tied to a session
- **Session photos**: Camera capture tied to a session
- **Conference report export**: Generate a PDF/document of attended sessions with notes and photos
- **Push notifications**: Reminders before picked sessions start
- **Programme update**: Fetch updated programme JSON from a URL without app rebuild

## App Name Ideas

Working title: **ConferenceNav**. Open to alternatives — "Prague Guide", "EAPC Nav", "ConfBuddy", or something with more personality.
