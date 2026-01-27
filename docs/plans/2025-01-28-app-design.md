# Where's Ben? - iOS App Design

## Overview

Two native iOS apps for tracking Ben's Prague trip (EAPC Conference, May 12-18, 2026):

| App | User | Purpose |
|-----|------|---------|
| **Where's Ben?** | Wife + kids | Dashboard showing location, status, flights, trip info |
| **Captain's Log** | Ben | Quick status updater with GPS capture |

## Architecture

```
Captain's Log (Ben's phone)
        │
        ▼
┌─────────────────────────────────────────────┐
│              Supabase                        │
│                                             │
│  Existing tables:                           │
│  ├── trip_segments (pre-planned schedule)   │
│  ├── status_override (manual updates)       │
│  └── config (trip details, contacts)        │
│                                             │
│  New tables:                                │
│  ├── push_tokens (device registration)      │
│  └── sent_notifications (dedup tracking)    │
│                                             │
│  Edge Function:                             │
│  └── Sends push on status change + schedule │
└─────────────────────────────────────────────┘
        │
        ▼
Where's Ben? (Wife's phone)
        │
        ├── Push notifications
        └── Live data polling/realtime
```

---

## Where's Ben? App

### Tab Structure

| Tab | Icon | Name | Content |
|-----|------|------|---------|
| 1 | 📍 | Where's Ben? | Live status, map, current location |
| 2 | ✈️ | Flights | All 4 flights with progress |
| 3 | 📋 | Trip Info | Schedule, hotel, contacts |
| 4 | ⭐ | Kids | Playful full-screen view |

### Header (Tabs 1-3)

- Title (tab-specific)
- Right side: Ben's current date/time (e.g., "Prague · 11:23pm")
- **Debug mode:** Tap date/time → time picker to scrub through trip

### Tab 1: Where's Ben? (Main View)

**1. Status Card (prominent)**
- Large icon/image with subtle glow animation
- Status text: "Flying to Dubai"
- Optional note: "Just took off, great views!"
- Timestamp: "Updated 10 mins ago"

**2. Map Card**
- Apple Maps showing current position
- Pin when stationary, animated plane when flying
- Flight path as dotted line
- Tap to expand full-screen

**3. Quick Info Row**
- Home time (Sydney)
- Weather at Ben's location
- Countdown until home

**4. Next Up Card**
- "Next: Landing in Dubai in 2h 15m"
- Or: "Ben presents in 4 hours! 🎤"

### Tab 2: Flights

**Summary cards (collapsed by default):**
- Flight number + route: "EK417 · Sydney → Dubai"
- Current/active flight has glowing highlight
- Tap to expand details:
  - Date/time (local)
  - Duration
  - Progress bar (when in-flight)
  - "Open in FlightRadar" button → WebView

**Sections:**
- "Outbound" (EK417, EK139)
- "Return" (EK140, EK412)
- Layover info between flights

### Tab 3: Trip Info

**1. Schedule Overview**
- Visual timeline of trip
- Key dates listed
- Presentation slot highlighted (when known)

**2. Accommodation**
- STAGES HOTEL Prague
- Address (tap → Apple Maps)
- Check-in/out times

**3. Contact Ben**
- WhatsApp call button (prominent)
- Phone number

**4. Emergency Contacts**
- Australian Consulate Prague
- Travel insurance company + policy number

**5. Useful Links**
- Hotel location
- Airport transfers (placeholder)

### Tab 4: Kids Mode

**Full-screen immersive:**

**Background:**
- Sky gradient (blue → soft orange horizon)
- Animated drifting clouds
- Sun/moon based on Ben's local time

**Content:**
- Big bouncy status icon (tap for animation)
- Text: "Daddy's on the plane!"
- Stylized map with Daddy's dot/plane
- Giant sleeps countdown: "3 sleeps until Daddy's home!"
- Tap countdown → stars sparkle

**Special moments:**
- Landing at Sydney → confetti burst
- Trip complete → "Daddy's home!" celebration

---

## Captain's Log App

### Design

Simple, quick, subtle nautical theme.

### Single Screen Layout

**Header:**
- "Captain's Log" title
- Auto-detected location: "📍 Dubai Airport"
- Current local time

**Quick Status Grid (3x3):**

| | | |
|---|---|---|
| ✈️ Taking off | 🛬 Just landed | 🏨 At hotel |
| 📍 At conference | 🍽️ Getting food | 😴 Going to sleep |
| ☕ Awake now | 🏠 Heading home | 💬 Custom... |

**Tap quick status:**
1. Grabs GPS
2. Sends to Supabase
3. Confirmation: "Sent! ✓"

**Tap "Custom":**
- Text field (or dictation)
- "Add a note for the family..."
- Send button

**History (collapsible):**
- Recent updates list

---

## Design Language

### Family View (Cozy)

- Background: Soft cream (`#FAF7F2`)
- Accent: Muted terracotta (`#C4846C`)
- Success/home: Soft sage (`#8FA98F`)
- Text: Warm charcoal (`#3D3D3D`)
- Cards: Subtle shadows, 16-20pt rounded corners
- Font: SF Pro Rounded

**Visual touches:**
- Time-of-day aware gradients on map
- Subtle glow behind status icon
- Smooth spring animations

### Kids View (Playful)

- Background: Bright sky gradient
- Chunky rounded text (SF Rounded Bold)
- Fluffy cloud decorations
- Bouncy, tappable elements
- Sparkles and confetti for special moments

### Iconography

- Placeholder emoji initially
- Designed to swap in custom illustrations/icons later

---

## Push Notifications

| Trigger | Message | Timing |
|---------|---------|--------|
| Captain's Log post | "Ben: [status/note]" | Immediate |
| Flight departure | "Ben's flight EK417 departs in 30 mins" | 30 mins before |
| Flight landing | "Ben should be landing in Prague soon!" | 30 mins before |
| Presentation | "Ben presents in 1 hour! 🎤" | 1 hour before |

**Not included (per design):**
- Auto goodnight messages
- Daily sleeps countdown push

---

## Test Mode

**Debug toggle:**
- Button in header reveals debug controls
- Date/time display becomes tappable
- Scrub through any point in the trip (May 12-18)
- Test all states: pre-trip, mid-flight, layover, conference, homecoming
- Push notifications work in test mode (actually sends)

**Build configurations:**
- `Debug`: Time offset toggle visible
- `Release`: Clean experience, no debug UI

---

## Database Additions

### Table: push_tokens

```sql
CREATE TABLE push_tokens (
    device_id    TEXT PRIMARY KEY,
    token        TEXT NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);
```

### Table: sent_notifications

```sql
CREATE TABLE sent_notifications (
    id           SERIAL PRIMARY KEY,
    trigger_type TEXT NOT NULL,  -- 'status', 'departure', 'landing', 'presentation'
    trigger_id   TEXT NOT NULL,
    sent_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## File Structure

```
WheresBen/
├── WheresBen/                      # Wife's app
│   ├── App/
│   │   └── WheresBenApp.swift
│   ├── Models/
│   │   ├── TripSegment.swift
│   │   ├── StatusOverride.swift
│   │   └── AppState.swift
│   ├── Views/
│   │   ├── MainTabView.swift
│   │   ├── WhereIsBen/
│   │   │   ├── WhereIsBenView.swift
│   │   │   ├── StatusCard.swift
│   │   │   ├── MapCard.swift
│   │   │   ├── QuickInfoRow.swift
│   │   │   └── NextUpCard.swift
│   │   ├── Flights/
│   │   │   ├── FlightsView.swift
│   │   │   └── FlightCard.swift
│   │   ├── TripInfo/
│   │   │   ├── TripInfoView.swift
│   │   │   ├── ScheduleSection.swift
│   │   │   ├── AccommodationSection.swift
│   │   │   └── ContactsSection.swift
│   │   └── Kids/
│   │       ├── KidsView.swift
│   │       ├── KidsStatusView.swift
│   │       ├── KidsMapView.swift
│   │       └── SleepsCountdown.swift
│   ├── Services/
│   │   ├── SupabaseService.swift
│   │   ├── LocationService.swift
│   │   └── NotificationService.swift
│   ├── Components/
│   │   ├── DebugTimeControls.swift
│   │   └── GlowingCard.swift
│   └── Assets.xcassets
│
├── CaptainsLog/                    # Ben's app
│   ├── App/
│   │   └── CaptainsLogApp.swift
│   ├── Views/
│   │   ├── LogEntryView.swift
│   │   ├── QuickStatusGrid.swift
│   │   └── HistoryView.swift
│   ├── Services/
│   │   ├── LocationService.swift
│   │   └── SupabaseService.swift
│   └── Assets.xcassets
│
├── Shared/                         # Shared code
│   ├── Models/
│   │   ├── TripSegment.swift
│   │   ├── StatusOverride.swift
│   │   └── Config.swift
│   └── Services/
│       └── SupabaseClient.swift
│
├── docs/
│   └── plans/
│       └── 2025-01-28-app-design.md
│
└── CLAUDE.md
```

---

## Trip Details Reference

### Flights

| Leg | Flight | Route | Depart (local) | Arrive (local) |
|-----|--------|-------|----------------|----------------|
| 1 | EK417 | Sydney → Dubai | Tue 12 May 20:10 | Wed 13 May 04:30 |
| 2 | EK139 | Dubai → Prague | Wed 13 May 08:35 | Wed 13 May 13:00 |
| 3 | EK140 | Prague → Dubai | Sat 16 May 16:10 | Sat 16 May 23:55 |
| 4 | EK412 | Dubai → Sydney | Sun 17 May 10:10 | Mon 18 May 06:05 |

### Hotel

- STAGES HOTEL Prague
- Ceskomoravska 19a, Prague, CZ-19000
- Check-in: Wed 13 May, 15:00
- Check-out: Sat 16 May, 12:00

### Conference

- EAPC World Congress 2026
- O2 Arena Prague
- May 14-16, 2026
- Ben presenting (time TBD)
