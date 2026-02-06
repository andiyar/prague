# Where's Ben? - iOS Apps

Two native iOS apps for tracking Ben's EAPC Prague conference trip (May 12-18, 2026).

## Apps

| App | Target | Purpose |
|-----|--------|---------|
| **WheresBen** | Wife's iPhone 17 (iOS 26) | Dashboard: location, flights, trip info, kids mode |
| **CaptainsLog** | Ben's iPhone | Quick status updater with GPS |

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
├── WheresBen/           # Wife's app (Xcode target)
├── CaptainsLog/         # Ben's app (Xcode target)
├── Shared/              # Shared models & services
├── docs/plans/          # Design documents
└── CLAUDE.md            # This file
```

## Trip Details

### Passenger
Dr Benjamin Wayne Thomas

### Flights (Emirates, Business Class, A380)
| Flight | Route | Depart | Arrive |
|--------|-------|--------|--------|
| EK417 | SYD→DXB | Tue 12 May 20:10 | Wed 13 May 04:30 |
| EK139 | DXB→PRG | Wed 13 May 08:35 | Wed 13 May 13:00 |
| EK140 | PRG→DXB | Sat 16 May 16:10 | Sat 16 May 23:55 |
| EK412 | DXB→SYD | Sun 17 May 10:10 | Mon 18 May 06:05 |

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
| Dubai Airport | 25.2532 | 55.3657 |
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
