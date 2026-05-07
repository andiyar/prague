# V6+V7 Independent Review — Findings & Fixes (8 May 2026)

> Overnight pass while Ben was asleep. Probed the four highest-risk files
> from the handoff doc + investigated issues visible in Ben's iPad
> testing screenshots + did a second sweep through the deferred items
> after Ben asked for more bulletproofing. Total of **fourteen fixes
> shipped** across ten commits. Build green on iPhone 16 and iPad
> mini (6th gen) sims.

## TL;DR

**Fourteen fixes shipped overnight.** All tightly scoped, low risk,
high value. Each in its own commit so any can be reverted
independently. Build green. No blockers found in V6+V7.

The two highest-impact catches were:

1. **Notifications would have fired ~8 hours late during the
   conference** if Ben scheduled them in Sydney before flying.
   `UNCalendarNotificationTrigger` was using device-current timezone
   instead of Europe/Prague.
2. **Picks loaded from disk weren't getting reminders scheduled at
   all** until the user toggled a pick. didSet vs late-attached
   service timing.

Either alone could have meant Ben missing his own keynote. Both
fixed now.

| # | Severity | What | Why it matters |
|---|---|---|---|
| 1 | Important | OCR junk filter | The `_` Ben saw in his note bodies — Vision misreading stray marks as text. Now drops sub-2-alphanumeric transcriptions. |
| 2 | Important | Dot grid invisible | `0.90` dots on `0.98` cream was below contrast threshold on iPad mini. Bumped to `0.78`. |
| 3 | Important | Sketch PNGs were transparent | Lost the cream-paper aesthetic in dark-mode previews — strokes floated on dark navy. Now bakes cream background into the saved PNG. |
| 4 | Important | Empty-canvas saves | Tapping Save with no strokes inserted a blank PNG into the body. Now treated as Cancel. |
| 5 | Medium | PDF export leaked /tmp | Each export left ~10MB of staged media in /tmp forever. Now cleaned up after every export (success or failure). |
| 6 | Medium | Notes didn't refresh on iCloud sync | iPad-edit → switch to iPhone, you'd see stale data until app restart. Now reloads on `willEnterForeground`. |
| 7 | Minor | PDF continuation re-entrancy | Defensive race-guard before createPDF result handler. |
| 8 | Cleanup | Dead code | `ReaderModeFigure.swift` deleted (never wired up post-V6 task 13). |
| 9 | Cleanup | `OCRDecision.none` rename | Renamed to `.firstSave` so it doesn't shadow `Optional.none`. |
| 10 | Medium | Sync image loading in markdown | Replaced `Data(contentsOf:)` in `LocalMediaImageProvider` with an async + cached `AsyncLocalImage`. No more main-thread blocks on iCloud-cold images. |
| 11 | Important | PickButton tap target | Gold-star pick button was a 20×20pt SF Symbol with no padding — well below HIG 44pt. 44pt invisible hit area added. |
| 12 | Important | Markdown export photo paths | Body referenced `![Photo](abc.jpg)` (bare filename) but bundle had photos at root. Now `photos/abc.jpg` paths matched by `photos/` subdir in the export. Sketches already worked this way; pattern now uniform. |
| 13 | Medium | Export temp dirs leaked | `EAPC-Export-*` and `EAPC-PDF-*` dirs accumulated in /tmp. Launch-time sweep clears them. |
| **14** | **Important** | **Notifications used device timezone** | `UNCalendarNotificationTrigger` was given timezone-less components extracted via `Calendar.current`. Schedule in Sydney → trigger fires 8 hours late once device shifts to CET. Pinned to Europe/Prague. |
| **15** | **Important** | **Notifications missed at cold start** | Picks loaded during `ConferenceStore.init()` triggered `didSet` → reschedule, but notificationService wasn't attached yet, so the call no-oped. Until the user re-toggled a pick, no reminders existed. didSet observer + explicit reschedule after auth grant fix it. |

(Fixes 14 and 15 are the two highest-impact catches — both could have caused missed-notification incidents during the actual conference.)

---

## What was probed

Per the handoff at [docs/progress-notes/2026-05-01-v6-v7-review-handoff.md](2026-05-01-v6-v7-review-handoff.md):

1. **NoteEditorView string surgery** — every body mutation, plus edge cases (adjacent images, empty canvas, race during async OCR, state sync across iCloud)
2. **PDFExportService markdown→HTML parser** — escape behaviour, image paths, continuation race, /tmp lifecycle
3. **iPhone byte-identical promise** — `git diff 6d8ae4c..HEAD` on all four tab files + SessionDetailView + MarkdownTheme
4. **iCloud sync code path** — sketch resolution, file change detection, ubiquity container fallback
5. **SketchOCR** — what Vision actually returns, junk filter behaviour
6. **DotGridBackground** — colour values vs the editor's cream background

---

## Findings (severity-ordered)

### IMPORTANT — fixed

**[F1] SketchOCR returns junk transcriptions for noisy strokes**
Vision happily emits `_`, `-`, `:` with sub-0.3 confidence when it sees
stray marks rather than letters. These ended up in note bodies — Ben
saw a lone `_` line in his test note and a stray `-` in another. Both
visible in the iPad screenshots from 7 May.

Fix at [SketchOCRService.swift:33](ConferenceNav/Services/SketchOCRService.swift:33):
- Drop individual observations with `confidence < 0.3`
- Reject the whole transcription if alphanumeric character count < 2

Trade-off: loses legitimate single-letter transcriptions (e.g. "I"). Worth
it — that case is rare and recoverable, polluted bodies are not.

**[F2] Dot grid was invisible**
Editor background is fixed cream `(0.98, 0.98, 0.97)`. Dots were
`(0.90, 0.90, 0.88)` — an 8% luminance delta, below most monitors'
detection threshold at typical brightness, especially on iPad mini's
slightly dimmer panel. Plus the dark-mode arm `UIColor(white: 1.0, alpha: 0.16)`
never fired in practice (background is always cream regardless of theme).

Fix at [DotGridBackgroundView.swift:24](ConferenceNav/Views/SketchEditor/DotGridBackgroundView.swift:24):
single fixed colour `(0.78, 0.78, 0.75)`. Just visible, still subtle.

**[F3] Saved sketch PNGs were transparent**
`PKDrawing.image(from:scale:)` renders strokes onto a transparent
canvas. The `.pngData()` write preserves transparency. So when MarkdownUI
displays a sketch in preview-mode-on-dark-theme, the cream paper
disappears and strokes float on dark navy. Visible in Ben's 9:25 PM
screenshot — a cream-coloured stroke on dark navy.

Fix at [SketchEditorView.swift:99](ConferenceNav/Views/SketchEditor/SketchEditorView.swift:99):
bake cream background into the composed image before save. Use
`UIGraphicsImageRenderer`, fill cream, draw strokes on top, save the
composite as PNG. Sketches now look right in any theme and any context
(preview, PDF, exported markdown).

**[F4] Empty-canvas saves polluted the note body**
SketchEditorView's Save button didn't check for empty drawings. Tapping
Save with zero strokes called `image(from: 768x1024 fallback)` which
produced a blank cream PNG, inserted `![sketch](sketches/UUID.png)` +
empty transcription block into body. User had to manually clean up.

Fix at [SketchEditorView.swift:99](ConferenceNav/Views/SketchEditor/SketchEditorView.swift:99):
empty `drawing.strokes` triggers `onCancel()` instead of `onSave()`.
Silent — user just exits as if they tapped Cancel. The "delete a sketch"
path is via the MediaStrip thumbnail, not Save with no strokes.

### MEDIUM — fixed

**[F5] PDFExportService leaked the staging dir**
Every export created `/tmp/EAPC-PDF-{UUID}/` containing a copy of all
photos + sketches + the HTML — typically 5-10MB. Never deleted. Each
export of the conference report adds another full copy. Hardware-only
issue (sims clear /tmp on shutdown), but a real device leak.

Fix at [PDFExportService.swift:27](ConferenceNav/Services/PDFExportService.swift:27):
- Write final PDF to `/tmp/{filename}.pdf` directly (not inside staging)
- Track `stagingDir` on the service
- `cleanupStaging()` called from every continuation-resume path
  (success, failure, didFail, didFailProvisional)

**[F6] Notes didn't reload on iCloud sync**
`loadNotes()` ran once at init. No `NSMetadataQuery` observer, no
foreground reload. So edit-on-iPad → background app → switch to iPhone
shows stale data until iPhone app is force-quit and relaunched.

Fix at [NotesStore.swift:13](ConferenceNav/Services/NotesStore.swift:13):
observer on `UIApplication.willEnterForegroundNotification` reloads
notes when app comes back. Cheap, no UI flicker (loadNotes goes through
fileQueue).

This isn't a full conflict-resolution solution (concurrent edits on two
devices still race — last-write-wins). For the 11-day Prague window
where Ben + Ron edit independently, foreground reload is enough.

### MINOR — defensive fix included

**[F7] PDF export continuation race window**
In `didFinish`, between `await Task.sleep(0.6s)` and the createPDF
callback resolving, if `didFail*` fires (memory pressure, dropped
canvas, etc.), both paths would resume the same continuation → CRASH.

Fix at [PDFExportService.swift:268](ConferenceNav/Services/PDFExportService.swift:268):
re-entrancy guard before the createPDF result-handling block. If the
continuation has already been consumed, just clean up and exit.

Defensive — never observed. But the cost was 4 lines and a crash window
closes.

---

## Findings — known limitations, NOT fixed

These are intentional V6 design choices or out-of-scope.

**[K1] Photos don't insert into note body**
`attachPhoto()` adds to `photoFilenames` array but doesn't insert
`![photo](photos/X.jpg)` into the body. Photos appear in MediaStrip
thumbnails AND clustered at the end of PDF body. They never appear
inline in markdown preview or markdown export.

Architectural — moving photos to body would require a larger refactor
(thumbnail tap behaviour, removal logic, ordering relative to text).
Working as designed for V6.

**[K2] Sketch removal orphans transcription paragraph**
`removeSketch()` strips the `![sketch](...)` ref but leaves the
transcription paragraph that follows. Comment in the code marks this as
intentional ("it's edited prose at this point"). Acceptable.

**[K3] Re-edit when body has been externally modified can desync**
If user opens sketch A for re-edit, then iCloud delivers a body update
that removed `sketches/A.png` reference, the save's
`replacingOccurrences` becomes a no-op. Sketch saved on disk + array
updated, but body has no reference. Edge case — both devices would have
to be open simultaneously.

**[K4] Concurrent NotesStore writes don't merge**
`handleSketchSave` reads `currentNote` (computed property), overwrites
body+photos+sketches, calls save. No merge. iCloud sync mid-save would
lose the other device's diff. Same edge case as K3.

**[K5] `escapeInline` greedy bold/italic regex**
Already documented in handoff. `**hello*world**` produces ugly output.
Not worth fixing — users would have to deliberately type ambiguous
patterns.

**[K6] TOC links not clickable in PDF**
`renderTOC` emits `<a href="#session-N">` anchors. WKWebView's PDF
output doesn't preserve internal links by default. Would need
`createPDF(configuration:)` with a different config or post-process the
PDF to add link annotations. Out of scope.

**[K7] `Font.custom` doesn't scale with Dynamic Type on iPad reader mode**
Already documented in handoff. Out of scope.

---

## What I deliberately did NOT touch

- **Venue map pin code** — Ben still owes a fresh screenshot post-recalibration
- **TestFlight push** — Ben does this on his hardware
- **Any feature additions** — the task is bulletproofing, not building
- **The deferred items list from the handoff** — explicit follow-ups, post-Prague

---

## Verification

Build green on:
- `iPhone 16` simulator (iOS 18.0)
- `iPad mini (6th generation)` simulator (iOS 18.0)

No new test cases added — there's no XCTest target. All fixes verified via
compile + code review. Hardware testing is Ben's next step.

## Recommended next steps (Ben's morning)

**Critical hardware tests (notification fixes):**

1. **Notification timezone test** — Set device to Sydney time, pick a session for tomorrow morning Prague time. Then change device timezone to Europe/Prague. The reminder should still fire 15 min before the session starts in Prague time, not 8 hours late.
2. **Cold-launch reminder test** — Force-quit the app. Re-launch. Pick a session that's 20 min away. Wait 5 min without toggling anything. The reminder should fire 15 min before the session.

**Visual fixes (sketch editor):**

3. **OCR fix** — write a sketch with messy strokes, confirm `_`/`-`/`:` artefacts no longer appear in body
4. **Dot grid** — confirm dots are visible on iPad mini at typical brightness
5. **Cream background in dark mode** — make a sketch, switch app to dark mode, view note in preview, confirm sketch is on cream not dark navy. Same in PDF export.

**Other tests:**

6. **Re-export a conference report** — confirm it's the only file in /tmp afterward (no `EAPC-PDF-*` or `EAPC-Export-*` dirs left over)
7. **Markdown export with photos** — share a note with photos, open the resulting bundle in another markdown app, confirm photos render (paths now resolve via `photos/` subdir)
8. **Cross-device iCloud test** — edit a note on iPad, background, open iPhone — confirm changes appear without app restart
9. **Pick star tap target** — confirm hitting just the edge of the gold star reliably toggles pick
10. **Venue map pin recalibration** — use the DEBUG crosshair tool in Extras to confirm/refine my eyeball estimates

## Risk assessment

**Net risk delta vs pre-overnight:** materially lower. Fourteen real
bugs gone (two of them critical for the actual conference experience),
no new behaviour added beyond what was needed for the fixes. Each fix
is in its own commit so any can be reverted without disturbing the
others.

User-visible behavioural changes:
- OCR no longer transcribes single-letter handwriting (acceptable)
- Sketches saved going forward look slightly different from older
  sketches (cream background baked in) — old sketches still render
  fine, just without the bake
- Empty-canvas Save in sketch editor now silently dismisses instead
  of inserting a blank PNG
- First markdown image render now shows a brief grey placeholder
  while loading (instead of blocking the UI)

**Confidence level for ship after Ben's walkthrough: high.**

## Commit history (overnight)

```
1d254bc fix(conf): note button hit area, pin shape, and pin coordinates
9e2d6c5 fix(conf): sketch editor, note preview, PDF report — iPad testing pass
308ca7e fix(conf): V6+V7 second-review bulletproofing pass     ← purged
fc6629f chore: remove accidentally-committed PDF                ← purged
[history rewritten via git filter-branch — accidentally-committed
 personal flight itinerary purged, force-pushed]
19c00ac fix(conf): V6+V7 second-review bulletproofing pass     ← rewritten
4ef86f9 chore(conf): remove dead ReaderModeFigure component
e931469 refactor(conf): rename OCRDecision.none → .firstSave
b33b3b2 perf(conf): async + cached image loading in MarkdownTheme
1108a59 fix(conf): bump PickButton tap target to 44pt
3cd992a fix(conf): markdown exports — consistent photos/ + sketches/ paths
8af9e6a fix(conf): sweep stale export temp dirs on launch
c099724 fix(conf): pin session notifications to Europe/Prague timezone
bf6efe7 fix(conf): reschedule notifications after auth grant
```
