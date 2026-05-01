# V6+V7 Independent Review Findings — 1 May 2026

Independent fresh-eyes review of branch `6d8ae4c..4c81f53` (26 commits). Build green on iPhone 16 + iPad mini sims. iPhone byte-identical claim **holds** for SessionDetailView (verified by diff). The per-task reviewers caught the obvious string-surgery bugs in NoteEditorView. What they missed is more cross-cutting: at least one looks like a runtime regression on the headline V6 feature, plus two PDF-rendering bugs and one iPad UX gap.

Severity legend: **Blocker** = fix before TestFlight; **Important** = fix before Prague if time; **Minor** = nit / acknowledged limitation.

---

## Blockers

### B1. Inline sketches almost certainly do not render in Preview mode

**File:** [ConferenceNav/Design/MarkdownTheme.swift](../../ConferenceNav/Design/MarkdownTheme.swift)
**Where the bug bites:** [ConferenceNav/Views/NoteEditorView.swift:248](../../ConferenceNav/Views/NoteEditorView.swift) — `Markdown(noteBody).markdownTheme(.conference(...))` in `previewMode`

After every sketch save, NoteEditorView inserts `\n\n![sketch](sketches/{uuid}.png)\n\n{ocr}\n` into the body ([NoteEditorView.swift:331](../../ConferenceNav/Views/NoteEditorView.swift)). The image path is **relative**.

`grep -rn "markdownImageProvider\|markdownBaseURL" ConferenceNav/` returns nothing. MarkdownUI 2.4.1's `DefaultImageProvider` delegates to NetworkImage 6.0.1, which calls URLSession on a relative URL — the load fails, no provider routes to `notesStore.sketchURL(...)`, and the user sees a broken-image placeholder where their sketch should be.

The V6 spec asserts ([2026-05-01-pencil-notes-pdf-export-design.md:54](../superpowers/specs/2026-05-01-pencil-notes-pdf-export-design.md)) that this works "exactly like photos do today (already supported — `![alt](filename)` resolves to local files)". I can't find any code path that supports this — pre-V6 photos were never inserted as inline image refs in body markdown; they lived in `photoFilenames` and rendered via the strip. So the precedent the spec relies on may not exist.

**Verify on simulator:** create a sketch in NoteEditorView on iPad, switch to Preview. If broken image / nothing renders, you need a custom image provider routing `sketches/X` and `photos/X` through `notesStore.sketchURL(...)` / `notesStore.photoURL(...)`.

**Fix sketch (~30 lines):** add `markdownImageProvider(...)` to the `Markdown(noteBody)` modifier chain returning `Image(uiImage:)` views from local file URLs.

---

### B2. PDF body multi-line paragraphs render `<br>` as literal `&lt;br&gt;` text

**File:** [ConferenceNav/Services/PDFExportService.swift:182](../../ConferenceNav/Services/PDFExportService.swift)

```swift
html += "<p>\(escapeInline(p.replacingOccurrences(of: "\n", with: "<br>")))</p>"
```

Substituted before `escapeInline` runs, so the literal `<br>` makes it into `escapeHTML(s)` ([line 204-208](../../ConferenceNav/Services/PDFExportService.swift)) which turns `<` → `&lt;` and `>` → `&gt;`. Final HTML: `<p>line1&lt;br&gt;line2</p>` — renders as readable text "line1\<br\>line2".

**Where it bites:** Vision OCR returns `lines.joined(separator: "\n")` ([SketchOCRService.swift:34](../../ConferenceNav/Services/SketchOCRService.swift)). Every multi-line OCR transcription sits in the body as a single paragraph with embedded `\n`s. Every Conference Report and All Notes PDF will show those transcriptions as `line1<br>line2<br>line3` literally.

**Fix (one-line):** replace `\n` AFTER `escapeInline` so the `<br>` survives escaping. Or use a sentinel placeholder.

```swift
let escaped = escapeInline(p)
let withBreaks = escaped.replacingOccurrences(of: "\n", with: "<br>")
html += "<p>\(withBreaks)</p>"
```

---

### B3. iPad users cannot delete photos or sketches from the note editor

**Files:**
- [ConferenceNav/Views/NoteEditorView.swift:54](../../ConferenceNav/Views/NoteEditorView.swift) — `if !photoFilenames.isEmpty && !CNLayout.isPad { photoStrip }`
- [ConferenceNav/Views/Components/MediaStrip.swift:64-92](../../ConferenceNav/Views/Components/MediaStrip.swift)

The X-to-delete button only exists in `photoStrip`, which is gated to iPhone-only. The iPad-only `MediaStrip` has tap-to-reopen (sketch) and tap-no-op (photo, [NoteEditorView.swift:71-72](../../ConferenceNav/Views/NoteEditorView.swift) — explicitly `break`), no long-press, no swipe, no delete affordance of any kind.

Ben is the iPad user. If he attaches a photo or sketch and decides he doesn't want it, the only way to remove it is to switch to iPhone (where the iPhone strip still renders that note's photos via iCloud sync) and tap X there. Sketches he can't remove on either device — there's no sketch X button anywhere.

This isn't a deferred item — it's a missing UX path for the primary device's primary new feature.

**Fix sketch (~50 lines):** add a long-press context menu (or X button on hover) to MediaStrip thumbnails that calls `removePhoto` / a new `removeSketch` (which also strips the `![sketch](...)` ref from `noteBody`).

---

## Important

### I1. PDF Conference Report drops notes for sessions you didn't pick

**File:** [ConferenceNav/Services/PDFExportService.swift:114](../../ConferenceNav/Services/PDFExportService.swift)

```swift
for session in picks {
    ...
    let sessionNotes = notes.filter { $0.sessionId == session.id }
```

The Markdown version of the same export ([NotesStore.swift:218-223](../../ConferenceNav/Services/NotesStore.swift)) explicitly merges picks + sessions-with-notes:

```swift
let extraSessionIds = sessionIdsWithNotes.subtracting(pickedIds)
let extraSessions = allSessions.filter { extraSessionIds.contains($0.id) }
let mergedSessions = pickedSessions + extraSessions
```

Two exports with the same name and stated purpose, different content. If Ben takes a serendipitous note on a session he didn't formally pick, the Markdown export keeps it; the PDF silently drops it. Likely uncommon during the conference but the silent drop is the worry — he'd never know it happened.

**Fix (~10 lines):** mirror the merge logic from `NotesStore.exportConferenceReport` in `PDFExportService.renderConferenceContent` (or pass a pre-merged `sessions` list into the mode).

---

### I2. PDFExportService has no `didFailNavigation` handler — failed loads hang the continuation forever

**File:** [ConferenceNav/Services/PDFExportService.swift:254-282](../../ConferenceNav/Services/PDFExportService.swift)

`WKNavigationDelegate` only implements `webView(_:didFinish:)`. If the file load fails (file URL sandbox issue, malformed HTML, anything), `didFinish` never fires, the continuation never resumes, and `await pdfExporter.export(...)` in [ExportView:259](../../ConferenceNav/Views/ExportView.swift) hangs forever. The "Building PDF…" overlay stays up indefinitely; only the re-entrancy guard at line 254 prevents tapping again.

The handoff calls out a fixed bug "WKNavigationDelegate guard early-return left the continuation hanging forever" — the guard inside `didFinish` was made safe (line 257-261), but the missing `didFailProvisionalNavigation` / `didFail` paths were not added.

**Fix (~10 lines):** add

```swift
nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    Task { @MainActor in
        self.continuation?.resume(throwing: error)
        self.continuation = nil
        self.webView = nil
    }
}
nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { /* same */ }
```

---

### I3. Markdown export filename collisions silently drop photos

**File:** [ConferenceNav/Views/ExportView.swift:199-213](../../ConferenceNav/Views/ExportView.swift)

`renameMap` keys photos by their internal filename → `slug-based-name.jpg`, where `slug` is derived from `presentationTitle` or `sessionTitle`. Two notes with title-slug collision (or same title across session and presentation level) produce the same new name. The second `copyItem` ([line 232](../../ConferenceNav/Views/ExportView.swift)) fails silently (`try?`), and the Markdown body references a file that's only one copy of one of the two.

EAPC has many similarly-titled posters in the same session. Probable in practice.

**Fix (~5 lines):** suffix collisions with a counter, or include a hash/short-uuid in the slug.

---

### I4. Race: Done before OCR finishes silently loses the new sketch insertion

**File:** [ConferenceNav/Views/NoteEditorView.swift:128-141, 310-350, 401-419](../../ConferenceNav/Views/NoteEditorView.swift)

```swift
.fullScreenCover(isPresented: $showSketchEditor) {
    SketchEditorView(
        ...
        onSave: { drawing, image, decision in
            showSketchEditor = false
            Task { await handleSketchSave(...) }
        }
    )
}
```

`handleSketchSave` runs as a Task — saves PNG + drawing files, awaits OCR (~1s), then mutates `noteBody`. If the user taps **Done** in the toolbar before that Task completes:

1. `saveAndDismiss` runs synchronously, saves the note with the OLD `noteBody` (no `![sketch](...)` ref).
2. `dismiss()` tears down NoteEditorView. `@State` is dropped.
3. The in-flight Task tries to update `noteBody` on a dead view — its updates are lost. The note on disk is the pre-sketch version.
4. The PNG and `.drawing` files exist on disk in `sketches/` but are referenced from nowhere → leaked + invisible to the user.

Tight window (~1 second) but realistic — Ben thumb-taps Done while the OCR spinner is up. He'd see no error, just notice the sketch is "missing" later.

**Fix sketch (~10 lines):** disable the Done button while a sketch save is in flight (mirror `isSaving` from SketchEditorView), or have `handleSketchSave` write the note synchronously before returning to the editor.

---

### I5. iPad List backgrounds: confirm `.cnPadMaxWidth` doesn't leave visible dead bands

**Files:** [ScheduleView.swift:73](../../ConferenceNav/Views/ScheduleView.swift), [SearchView.swift:119](../../ConferenceNav/Views/SearchView.swift), [MyPicksView.swift:77](../../ConferenceNav/Views/MyPicksView.swift), [ExtrasView.swift:116](../../ConferenceNav/Views/ExtrasView.swift)

`cnPadMaxWidth` constrains the inner view to 720pt then re-expands the outer to `.infinity` for centring. Lists and ScrollViews have their own implicit chrome; constraining width on iPad may or may not look right with the inset-grouped style (especially in dark mode where the surface colour matters). Pre-conference test plan calls out "iPad mini portrait (primary): each tab loads with iPad-polished proportions" — confirm visually before TestFlight.

Specifically check ExtrasView — `.listStyle(.insetGrouped).cnPadMaxWidth(...)` is the most likely candidate to look weird because the inset-grouped list paints rounded cards that may not align nicely inside a 720pt frame on a 1024pt-wide iPad mini portrait.

---

## Minor

### M1. SessionNote round-trip loses content for titles containing `"`

**File:** [ConferenceNav/Models/SessionNote.swift:140](../../ConferenceNav/Models/SessionNote.swift)

`trimmingCharacters(in: CharacterSet(charactersIn: "\""))` strips outer quotes but `\"` escapes from serialisation aren't decoded. Title `Foo "Bar"` round-trips as `Foo \"Bar\"`. EAPC programme titles don't seem to use double quotes, so likely never hits, but the data-loss is silent if it does.

### M2. `replaceTranscriptionAfterImage` "no paragraph after image" fallback appends to end of body

**File:** [ConferenceNav/Views/NoteEditorView.swift:358-361](../../ConferenceNav/Views/NoteEditorView.swift)

If the body has no `\n\n` after the image ref (mid-paragraph image, or image at end with no trailing paragraph break), the fallback appends transcription to the END of the body, not after the image. Reachable only via manual editing — auto-generated insertion always uses `\n\n` separators.

### M3. `notesStore.sketchOrPhotoURL` is functionally dead

**File:** [ConferenceNav/Services/NotesStore.swift:185-187](../../ConferenceNav/Services/NotesStore.swift)

Used only as a fallback in [ExportView:269](../../ConferenceNav/Views/ExportView.swift) for filenames without a `photos/` or `sketches/` prefix — which never happens because `allMediaFilenames` always emits prefixed paths. Safe to delete with `ReaderModeFigure.swift` in a cleanup pass.

### M4. PDF cover/TOC/session may produce a blank page between TOC and first session

**File:** [ConferenceNav/Resources/report.css:18, 37, 44](../../ConferenceNav/Resources/report.css)

`.cover { page-break-after: always }` → `.toc { page-break-after: always }` → `.session { page-break-before: always }`. Adjacent `page-break-after: always` + `page-break-before: always` should collapse in WebKit but it depends on quirks. Visual confirm only.

### M5. SketchEditor Cancel discards strokes without confirmation

**File:** [ConferenceNav/Views/SketchEditor/SketchEditorView.swift:72](../../ConferenceNav/Views/SketchEditor/SketchEditorView.swift)

If Ben sketches for 5 minutes and accidentally taps Cancel, all work is lost silently. Could add a "Discard sketch?" confirmationDialog when `drawing.strokes != initialDrawing.strokes`.

### M6. `iPadHeader` uses raw `Font.custom("New York", size: 15).italic()` for presenter line

**File:** [ConferenceNav/Views/SessionDetailView.swift:80](../../ConferenceNav/Views/SessionDetailView.swift)

Inconsistent with the `CNFonts.readerHeadline` / `readerCaption` token approach. Cross-cutting cleanup.

### M7. `OCRDecision.none` ambiguous next to `Optional.none`

Already in deferred items. Rename to `.firstSave` post-conference.

### M8. `MediaStrip` and `SketchEditor` use raw RGB literals for navy/teal/gold

Already in deferred items.

### M9. Synchronous `Data(contentsOf:)` for thumbnails

Already in deferred items. Will scale fine for ~50 thumbnails.

### M10. `Font.custom` on iPad reader mode loses Dynamic Type scaling

Already in deferred items.

### M11. `PKToolPicker.setVisible(false, ...)` race

Already in deferred items. Hardware-only verification.

---

## Verified — looks good

- **iPhone byte-identical**: `git diff 6d8ae4c..HEAD -- ConferenceNav/Views/SessionDetailView.swift` against `6d8ae4c` shows the iPhone branch in the new `else { ... }` differs from pre-V7 by one comment line and one `cnPadMaxWidth` modifier on the outer wrapper. Header/post-header/PresentationRow body all unchanged. ✅
- **MarkdownTheme iPhone branch**: 7-line diff, only adds an iPad branch — iPhone path unchanged. ✅
- **Sketch round-trip serialisation**: SessionNote DEBUG preview verifies `sketchFilenames` round-trips through YAML. ✅
- **Sketch path resolution end-to-end** (PDF only): body emits `sketches/X.png`, `allMediaFilenames` prefixes, staging copies to matching path, mediaURLProvider strips correctly. ✅
- **Sketch + photo `hasNote(...)` predicates** updated symmetrically across NotesStore and `notesWithContent`. ✅
- **PDF re-entrancy** guarded at the call site (`isExportingPDF` in ExportView). ✅
- **Tab polish** is single-line `.cnPadMaxWidth(...)` per file, no other touches. iPhone returns `.infinity` from cnPadMaxWidth. ✅

---

## Suggested fix order

1. **B2** (PDF `<br>` escape) — one-liner, ships immediately.
2. **B3** (iPad delete affordance) — small, no architecture change.
3. **B1** (Markdown image provider) — verify in simulator first; if broken, ~30-line fix.
4. **I1** (PDF report includes notes for non-picked sessions) — small.
5. **I2** (didFailNavigation handler) — small.
6. **I4** (race on Done while OCR running) — small, isolating Save during in-flight Task.
7. **I3** (rename collision) — defer if low-risk in the actual notes Ben writes.
8. **I5** (visual confirm of iPad list bands) — done during walkthrough, no code change needed unless something looks off.

The minor items are cleanup that can wait for a post-Prague PR.

---

## What I didn't verify

- Hardware behaviour on iPad mini + Pencil. Sketch flow, PKToolPicker race, OCR quality on real handwriting — out of scope.
- Whether `Bundle.main.url(forResource: "report", withExtension: "css")` actually resolves at runtime (the Resources/ folder needs to be in the bundle). Build succeeds, but a missing CSS reference would only show as plain unstyled HTML in PDF — visual check during walkthrough.
- iCloud Drive sync of `.drawing` files end-to-end. The code path looks fine but I didn't test cross-device.
- VoiceOver/accessibility on the SketchToolbar — labels are present per the `.accessibilityLabel(...)` chain but rotor navigation order on real device is something to confirm during hardware testing.
