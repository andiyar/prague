# Progress Note — ConferenceNav Status (1 May 2026)

> Handoff note from the previous session. Two things to do: (1) fix venue map pin issues, (2) hear out Ben's new concept idea.

## Where things stand

**Programme data: feature-locked candidate ✅**
- Refreshed from Exordo on 30 April. 97 sessions / 1130 presentations now bundled in `ConferenceNav/Resources/programme.json`.
- `lastUpdated` stamp = "30 April 2026" in `ConferenceStore.swift`.
- Both Ben's talks confirmed present:
  - Thu 14 May, Printed Posters Hall: *"The Comfort Zone: When familiar prescribing leads to loss of symptom-directed treatment"*
  - Fri 15 May, **C1, 14:15-15:45**: *"Antisecretory Prescribing Patterns Before and After the SILENCE Trial"*
- All committed and pushed (commit `d586d37`).

**Repeatable refresh in place:**
- `data/eapc/refresh.sh` — pulls + diffs vs canonical, `--apply` flag swaps in.
- `data/eapc/diff_programme.py` — structural diff (sessions added/removed, title/venue/time changes, presentation count changes).
- Method documented in `CLAUDE.md` under EAPragueC 2026 → "Refreshing programme data".

**V4 redefined** (was: in-app URL fetch). Now treated as a release gate — bundled JSON is the finalised programme, no runtime fetch needed (Ben will be flying to Prague, no network reliability assumed). Done.

**App build state:**
- Source code is current and committed.
- 🚧 Not yet rebuilt / pushed to TestFlight. Ben to do this in Xcode when ready.

## What's outstanding

### 1. Venue map pin issues (V5 polish — the actual reason for the new session)

**Symptoms reported by Ben:**
- Pins "often hit the room next door" — positions are close but not quite right
- Pins "look more like blobs than pins"

**Diagnostic context already loaded:**
- `ConferenceNav/Models/VenueMap.swift` — catalog with normalised (0–1) pin coordinates for 9 rooms (C1/C2/C3, D3/D4, D7/D8/D9, Hall A). Comments say target = "centre of each room's labelled rectangle".
- `ConferenceNav/Views/VenueMap/VenueMapPin.swift` — teardrop shape, 28pt size. **Pulse ring scales to 2.5× with 0.6 opacity fading to 0** — this is the likely "blob" cause, especially in screenshots where the halo is mid-animation.
- `ConferenceNav/Views/VenueMap/VenueMapThumbnail.swift` — uses `VenueMapPin(size: 32)` with default `pulse: true`.

**Initial visual analysis** (suspected position issues, eyeballed from JPGs — needs verification):
- **Hall A (Floor 0)**: catalog `(0.46, 0.58)` → looks too low. Hall A label centre appears closer to `y ≈ 0.46`. Pin probably lands in foyer area below the hall.
- **C3/C2/C1 (Floor 3)**: `x = 0.07` → rooms look centred closer to `x ≈ 0.10`.
- **D7/D8/D9 (Floor 3)**: `y = 0.78` → bottom-row centres look closer to `y ≈ 0.81–0.83`.

**Ben was about to share a screenshot** showing the actual misalignments — that wasn't received before context-switching. **First action in next session: get the screenshot.**

**Existing tooling that helps:**
- DEBUG-only crosshair toggle in `VenueMapView` toolbar marks every catalogued pin position. This is the right tool for systematic verification — Ben can toggle it on per-floor and we can read off which pins land in which rooms.
- DEBUG-only date picker in Extras → "Venue Map Debug" lets us validate "My Day" overlay before the conference.

**Proposed fixes (await Ben's screenshot before locking in):**

*Position fixes* — nudge coordinates in `ConferenceNav/Models/VenueMap.swift` based on screenshot evidence and crosshair sweep.

*Appearance fixes* — drop pulse on the thumbnail (small preview, the card itself is the visual), keep a gentler pulse on full-screen map (slower 5s, smaller 1.5× scale, lower starting opacity 0.3). Or drop pulse entirely if Ben prefers a clean static pin.

### 2. New concept idea (Ben to introduce in next session)

Ben mentioned wanting to discuss a "new concept idea" alongside the venue map fix. Open question — bring fresh ears.

## Key files for the next session

| File | What it does |
|------|--------------|
| `ConferenceNav/Models/VenueMap.swift` | Catalog with normalised pin coordinates — **edit here for position fixes** |
| `ConferenceNav/Views/VenueMap/VenueMapPin.swift` | Teardrop pin + pulse animation — **edit here for blob appearance fix** |
| `ConferenceNav/Views/VenueMap/VenueMapThumbnail.swift` | Cropped preview card on session detail |
| `ConferenceNav/Views/VenueMap/VenueMapView.swift` | Full-screen map with zoom/pan/floor-switcher/crosshair toolbar |
| `ConferenceNav/Assets.xcassets/Floors/*.imageset/*.jpg` | Floor 0–3 + Meeting Hub plans (~1.7 MB) — bundled |
| `data/eapc/refresh.sh` | Run pre-conference for last-minute programme updates |

## Recommended workflow for next session

1. **Get Ben's screenshot** of pins-in-wrong-rooms — confirms which specific rooms need nudging.
2. **Toggle the DEBUG crosshair** on each floor (Ben in the running app), screenshot per floor — gives us all 9 pin positions to assess at once.
3. **Update `VenueMap.swift`** with corrected coordinates.
4. **Decide on pulse**: keep, gentler, thumbnail-off-only, or kill entirely.
5. **Hear out the new concept idea**.
6. **Rebuild → TestFlight** if and only if Ben's happy with the result. After this build there should be no further code changes — the conference is in 13 days.
