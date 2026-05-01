# Design Spec — Pencil Notes & PDF Export (V6)

**Status:** Draft for review
**Date:** 2026-05-01
**Authors:** Ben + Claude
**Target:** EAPragueC 2026 (ConferenceNav)

## Why

Ben has an iPad mini + Apple Pencil Pro. Thumb-typing Markdown notes during sessions doesn't fit how he wants to work — he'd rather scribble freely (text + arrows + diagrams) and synthesise later. The existing photo attachment flow handles printed slides and posters; sketches are the missing third input alongside typed text and photos.

Ron will also use the app and won't touch Markdown willingly. The exported "Conference Report" should be readable as a PDF straight out of the share sheet — no Markdown viewer required.

## Goals

1. **Pencil-first sketch capture** — open a PencilKit canvas from the note editor, scribble freely, save as both editable ink (PKDrawing) and a rendered PNG.
2. **Inline image-then-text flow** — sketches appear inline in the note body as image references, with their OCR transcription rendered immediately below as editable Markdown.
3. **On-device OCR via Vision** — automatic handwriting recognition pass after each sketch save, written into the note body as a paragraph the user can edit or delete.
4. **PDF export** — Conference Report + All Notes get a PDF variant alongside the existing Markdown export. Tappable TOC, per-session page breaks, page numbers, embedded images.
5. **Keep existing Markdown exports** — Ben uses them. No regression.
6. **iPad-friendly** — sketch flow assumes iPad + Pencil; the rest of the app continues to work unchanged on iPhone.

## Non-Goals

- **No real-time ink-to-text in the typed editor.** That's Scribble's job and Apple already provides it system-wide where it makes sense.
- **No replacement of typed Markdown notes.** Sketches are additive — a third input alongside typed text and photos.
- **No multi-page sketch documents.** One sketch = one canvas. If Ben wants more, he creates another sketch attachment.
- **No collaborative or shared sketching.** Sketches stay local (synced via iCloud Drive like the rest of the notes).
- **No advanced ink editing** (lasso, transform, layers). PencilKit's stock tool palette is the whole UI surface.
- **No ink replay / animation.** Sketches export as static PNGs in PDF and Markdown.

## User Flow

### Capturing a sketch

1. In `NoteEditorView`, alongside the existing **Photo** button, a new **Sketch** button (pencil icon, teal). On iPhone: visible but disabled with a tooltip ("Use iPad with Apple Pencil"). On iPad: enabled.
2. Tap **Sketch** → full-screen `SketchEditorView` slides up with a `PKCanvasView` and the standard `PKToolPicker` (pen/pencil/marker/eraser/colour/ruler).
3. Ben scribbles. Pencil-only input enforced (`drawingPolicy = .pencilOnly`) so resting his palm doesn't draw — finger pans/scrolls instead.
4. Top bar: **Cancel** (left), session title in the middle, **Save** (right). Save triggers OCR before dismiss.
5. On Save:
   - Render the canvas to a PNG (high resolution, retina-aware) → save to `notes/sketches/{uuid}.png`
   - Save the editable `PKDrawing` data → `notes/sketches/{uuid}.drawing` (so Ben can reopen and add to it)
   - Run a Vision OCR pass over the PNG (async, with a small "Transcribing…" spinner)
   - Append to the note body:
     ```
     ![sketch](sketches/{uuid}.png)

     {OCR transcription, or empty paragraph if recognition failed}
     ```
   - Dismiss back to `NoteEditorView`, cursor positioned after the appended block so Ben can immediately keep writing.

### Editing existing content

- The note body remains plain Markdown. Sketches show in the **Preview** tab via MarkdownUI exactly like photos do today (already supported — `![alt](filename)` resolves to local files).
- Tap a sketch image in the editor's photo strip (now a "media strip" — photos + sketches mixed) to either reopen the sketch in the canvas (PKDrawing exists) or remove it.
- The OCR'd text is just regular Markdown body — Ben edits, deletes, reformats it however he wants.

### Exporting

The Export tab gains two new rows:

| Existing row | New row |
|---|---|
| Conference Report (Markdown) | **Conference Report (PDF)** |
| All Notes (Markdown) | **All Notes (PDF)** |

Markdown rows stay exactly as they are. PDF rows produce paginated, navigable PDFs.

## Data Model

### `SessionNote` (extended)

The body remains plain Markdown — sketches are referenced inline like photos. We add a parallel filename array:

```swift
var sketchFilenames: [String]   // e.g. ["sketches/abc-123.png"]
```

Front-matter gains a `sketches:` block mirroring the existing `photos:` block. Parser updates symmetrically.

**Why a separate array vs lumping into `photoFilenames`?**
- Distinct file lifecycle (the `.drawing` editable companion file)
- Distinct UI affordance (tap to reopen in canvas vs photo viewer)
- Cleaner export logic (sketches and photos can be styled differently in PDF if we want)

### File layout (iCloud Drive Documents/Notes/)

```
Notes/
├── session-12.md              ← existing
├── presentation-456.md         ← existing
├── photos/
│   └── {uuid}.jpg             ← existing
└── sketches/                   ← NEW
    ├── {uuid}.png             ← rendered canvas, used in Markdown/PDF
    └── {uuid}.drawing          ← PKDrawing binary, used to reopen
```

The `.drawing` file is the source of truth for re-editing; the `.png` is the export artefact. Both share a UUID stem so they're trivially paired.

## Implementation Sketch

### New files

> See V7 spec `2026-05-01-ipad-first-redesign-design.md` for the full sketch-editor file layout. V6 + V7 ship as one work order; the sketch editor's directory structure follows V7's break-down.

| File | Purpose |
|---|---|
| `ConferenceNav/Views/SketchEditor/SketchEditorView.swift` | Full-screen sketch editor (top toolbar + canvas) |
| `ConferenceNav/Views/SketchEditor/SketchToolbar.swift` | Top tool row (pen / pencil / marker / eraser / colour / undo / redo) |
| `ConferenceNav/Views/SketchEditor/PKCanvasRepresentable.swift` | `UIViewRepresentable` for `PKCanvasView` |
| `ConferenceNav/Views/SketchEditor/DotGridBackgroundView.swift` | Dot-grid background `UIView` |
| `ConferenceNav/Services/SketchOCRService.swift` | `VNRecognizeTextRequest` wrapper, returns transcription string |
| `ConferenceNav/Services/PDFExportService.swift` | Markdown → HTML → WKWebView PDF pipeline |
| `ConferenceNav/Resources/report.css` | CSS for the HTML render (mirrors `MarkdownTheme` palette) |

### Modified files

| File | Change |
|---|---|
| `ConferenceNav/Models/SessionNote.swift` | Add `sketchFilenames`, extend YAML serialise/parse |
| `ConferenceNav/Services/NotesStore.swift` | Sketch save/load/delete; expose `sketchURL(filename:)`; include sketch filenames in `allPhotoFilenames` (or rename to `allMediaFilenames`) so exports pick them up |
| `ConferenceNav/Views/NoteEditorView.swift` | Add Sketch button, sketch-aware media strip, Save flow appends image + transcription block to body |
| `ConferenceNav/Views/ExportView.swift` | Two new rows for PDF variants; route through `PDFExportService` |
| `ConferenceNav/project.yml` | No target changes (already universal). Add `NSPhotoLibraryAddUsageDescription` if not present. |

### PencilKit integration

- `PKCanvasView` wrapped in `UIViewRepresentable`.
- `PKToolPicker` attached to the canvas's window scene; auto-shows when canvas is first responder.
- `drawingPolicy = .pencilOnly` (iPad+Pencil only); on iPhone the editor view simply isn't presentable (Sketch button disabled).
- Canvas dimensions: A4-ish portrait aspect (e.g. 2480×3508 px) so exported PNG looks right on a PDF page.

### Vision OCR

- `VNRecognizeTextRequest` with `recognitionLevel = .accurate`, `recognitionLanguages = ["en-GB", "en-US"]`, `usesLanguageCorrection = true`.
- Pass the rendered PNG (CGImage) to `VNImageRequestHandler`.
- Concatenate top candidates from each `VNRecognizedTextObservation` in reading order (top-to-bottom, left-to-right by bounding box).
- Async via Swift concurrency; UI shows a small "Transcribing…" overlay (≤ ~1 sec for typical pages on modern iPads).
- Empty result handled gracefully — appended paragraph is just blank.

### PDF export (HTML → WKWebView)

The path: build a single HTML string from the report content, load into an off-screen `WKWebView`, await `viewport` ready, then call `webView.createPDF` (iOS 14+).

**HTML structure:**

```html
<html>
  <head><style>{report.css}</style></head>
  <body>
    <header><h1>EAPC 2026 — Conference Report</h1><p>Ben Thomas · 14–16 May 2026</p></header>
    <nav id="toc">
      <h2>Contents</h2>
      <ol>
        <li><a href="#s-thursday">Thursday, 14 May</a></li>
        <li><a href="#session-12">Session title</a></li>
        ...
      </ol>
    </nav>
    <section id="s-thursday" class="day"><h2>Thursday, 14 May</h2></section>
    <article id="session-12" class="session">
      <h3>Session title</h3>
      <p class="meta">09:00–10:30 · Hall A</p>
      <!-- rendered Markdown body, with image src rewritten to file:// paths -->
    </article>
    ...
  </body>
</html>
```

**CSS hits:**
- `@page { size: A4; margin: 18mm; }`
- `.session { page-break-before: always; }`
- Page numbers via `@page { @bottom-right { content: counter(page); } }` (WebKit supports this)
- Print-friendly typography matching `MarkdownTheme` (New York for headings, system serif body, navy/gold accents)
- Images: `max-width: 100%; max-height: 70vh;` to prevent tall sketches eating multiple pages

**TOC links** become valid PDF internal links via WebKit's `createPDF`. PDF outline / bookmarks: WebKit's `createPDF` will also synthesise a bookmark tree from `<h1>`/`<h2>`/`<h3>` headings — visible in Apple Books and Files.

**Image references:** the existing `exportWithPhotos` flow writes everything to a temp directory with rewritten filenames. PDF export uses the same temp directory and the HTML's `<img src>` points to those files via `file://` URLs. WKWebView is loaded with that temp dir as its base URL so relative paths resolve.

### Export packaging

- **Markdown export** (unchanged): `.md` file + photos + sketches (PNGs) bundled in a temp dir, share sheet hands the lot to AirDrop / Files / Mail.
- **PDF export**: single `.pdf` file (images embedded). No companion files, no zip, no fuss.

## Edge Cases

- **iPhone user opens a note with sketches** — sketches still render in preview and in exports. They just can't be created or edited (Sketch button disabled).
- **Vision OCR fails / returns gibberish** — empty paragraph is appended; Ben can write his own caption or delete the line break.
- **Reopening an old `.drawing` file on a future iOS version** — PKDrawing data is forward-compatible (Apple has maintained format compatibility since iOS 13).
- **Sketch deleted from the editor** — both `.png` and `.drawing` files are removed; image reference is stripped from body; OCR'd paragraph below is left intact (it's edited prose at that point — not safe to auto-delete).
- **iCloud sync conflict on a `.drawing` file** — same handling as photos: last-write-wins via iCloud Drive's coordinator. Acceptable because notes are single-user-per-device.
- **PDF for an empty report** — disable the row (already disabled when `myPickedSessions` and `notesWithContent` are both empty).
- **Very long single sketch** (Ben fills A4 portrait edge to edge) — capped at `max-height: 70vh` in CSS so it never spans more than one page; remaining content flows on next page.

## Decisions (locked 2026-05-01)

1. **OCR placement** — inline (image, transcription, image, transcription).
2. **Editable transcription** — yes, body Markdown after insertion.
3. **Re-OCR on reopened sketches** — when Ben edits an existing sketch and saves, prompt: **Replace transcription** / **Append** / **Skip OCR**. Default highlight: Replace.
4. **Sketch background** — dot grid. Subtle (#E5E5E0 light, #2A2A35 dark), spacing roughly 24pt. Pencil-friendly, doesn't fight the ink.
5. **PDF cover page** — Conference Report only (All Notes skips it). Cover contains:
   - "EAPC 2026 — Conference Report" (large, navy, New York serif)
   - User's full name — `ben` → **Benjamin Thomas**, `ron` → **Ronald Wai** (looked up from current user identity)
   - Dates: "14–18 May 2026"
   - Stats line: "X picks · Y notes · Z sketches"
   - Generated date in small gold caption
6. **PDF orientation** — A4 portrait throughout.

### Name mapping

```swift
private func fullName(for userId: String) -> String {
    switch userId {
    case "ben": return "Benjamin Thomas"
    case "ron": return "Ronald Wai"
    default: return userId.capitalized
    }
}
```

Lives in `PDFExportService` (cover page only — doesn't affect the rest of the app).

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Vision OCR quality on Ben's handwriting is poor | Medium | Low | Inline placement means bad OCR is just an editable line — easy to fix or delete. Ink is preserved as ground truth. |
| WKWebView PDF generation produces ugly output | Low | Medium | CSS is fully under our control. We iterate against a sample report with sketches before locking. |
| PencilKit performance on iPad mini (older A15-class GPU) | Very low | Low | PencilKit is heavily optimised by Apple for exactly this device. No concern. |
| Conference is in 13 days; we ship a regression | Medium | High | Feature is fully additive — no existing behaviour changes. New rows in Export tab, new button in editor. Old flows untouched. Ship behind no flag, but verify existing exports still work. |
| iPad-only feature confuses iPhone users | Low | Low | Sketch button disabled on iPhone with a clear tooltip. |

## Testing Plan

- **Manual on iPhone**: existing flows (photo + typed Markdown notes) unchanged. New PDF exports work. Sketch button disabled.
- **Manual on iPad mini + Pencil**: full sketch flow works end-to-end. OCR returns plausible text on a known-good handwritten sample. Re-opening a saved sketch loads the editable PKDrawing.
- **Manual export test**: Conference Report PDF opens cleanly in Apple Books, Files, Preview. TOC links jump to correct pages. Outline appears. Images render at sensible sizes.
- **Edge case**: empty notes, picks-only report, notes-only report. Each renders without errors.
- **Cross-device**: iCloud Drive sync — sketch created on iPad appears on iPhone (read-only access works).

## Out of Scope (V7+)

- Lasso/transform tools beyond stock PencilKit
- Custom CSS themes for PDF export (light/dark, formal/casual)
- Audio recording attached to sessions
- Real-time collaboration on notes
- Export to DOCX / RTF

## Sign-off

Once Ben has reviewed and answered the **DECISION NEEDED** points (OCR re-run UX, sketch background, PDF cover page), Claude writes the implementation plan and starts coding.
