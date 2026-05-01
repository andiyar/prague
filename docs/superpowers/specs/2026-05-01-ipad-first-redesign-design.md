# Design Spec — iPad-First Redesign (V7)

**Status:** Locked
**Date:** 2026-05-01
**Authors:** Ben + Claude
**Target:** EAPragueC 2026 (ConferenceNav)
**Ships before:** 12 May 2026 (alongside V6)

## Why

Ben will use his iPad mini (with Apple Pencil Pro) as his primary capture device during the conference. The current build runs on iPad in compatibility mode — iPhone layouts stretched to fill the screen. With V6 adding PencilKit sketches, the iPad becomes a first-class target and the layout needs to feel native rather than scaled-up.

Ron is iPhone-only. V7 changes are scoped to **iPad idiom only** so Ron's experience is untouched.

## Goals

1. **iPad-native layouts at idiom = `.pad`** — typography, spacing, and proportions tuned for iPad mini portrait.
2. **Reader-mode session detail** — generous side margins, serif body, sketches/photos rendered as inline figures with captions.
3. **Pencil-first sketch editor** — full-screen canvas, custom top toolbar with the most-used tools, dot-grid background edge-to-edge.
4. **Notebook-style note editor** — single column, comfortable line length, persistent bottom strip with `+ Sketch` / `+ Photo` actions and existing media thumbnails.
5. **Polished tab content** — Schedule / Search / My Picks / Extras retain the same structure but get iPad-tuned card sizing, padding, and density.
6. **Cross-device sync** is already free via existing infrastructure — no new sync code.
7. **iPhone unchanged** — no regressions, no visible changes for Ron.

## Non-Goals

- **No NavigationSplitView / sidebar.** Ben uses iPad mini portrait "like a notebook". Sidebar feels cramped and works against that mental model.
- **No landscape-specific layout.** Portrait works in both orientations; we do not optimise for landscape on iPad mini.
- **No iPad Pro / iPad Air-specific layouts.** Ben uses iPad mini only. Larger iPads will get the same iPad layout — fine, just not separately tuned.
- **No multi-window / Split View / Slide Over support.** Single-app experience.
- **No keyboard shortcuts.** Pencil + touch only.
- **No drag-and-drop between apps.** Sketches stay in-app.
- **No re-architecture of the tab structure.** Same 4 tabs.

## Out-of-Scope (V8+)

- Sidebar layout for iPad Pro
- Landscape-optimised dual-pane mode
- Hardware keyboard support
- iPad-to-iPhone Handoff

## User Flow

### Detection

A central helper:

```swift
extension UIUserInterfaceIdiom {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}
```

Layout-affecting code reads this once at view-builder time. We don't try to live-respond to iPad-Phone idiom changes (impossible during a session).

### Session detail (the hero view)

When `idiom == .pad`:

- Outer container caps at `max-width: 600pt`, centred horizontally
- Title: New York serif, 32pt, line-height 1.18, navy
- Meta row (date · time · venue): SF Pro caption, uppercase, 11pt, tracked
- Presenter line: italic teal, 16pt
- Body Markdown rendered with serif font (matching `MarkdownTheme`), 18pt, line-height 1.5
- Inline images (`![alt](path)`) rendered as figures: full content-width, subtle border, italic SF Pro caption below pulled from the immediately-following paragraph if it's short prose (≤ 100 chars)
- Pin row, picked star, notes row: existing components but with bigger padding (12pt internal, 8pt vertical between)
- Scroll behaviour unchanged

On iPhone, the existing layout stays exactly as is.

### Sketch editor (new in V6, designed in V7)

Full-screen presentation when invoked from the note editor. Layout (top to bottom):

1. **Status bar** (system)
2. **App bar** (navy `#002664`, 44pt tall):
   - **Cancel** (left, white, 16pt) — discards any new strokes since open
   - **Session title** (centre, 14pt, white, semibold, truncated)
   - **Save** (right, white, 16pt, semibold) — triggers save → OCR → dismiss
3. **Tool row** (darker navy `#001A44`, 40pt tall, horizontal scroll if needed):
   - Pen
   - Pencil
   - Marker / Highlighter
   - Eraser (vector eraser; tap again to toggle pixel mode)
   - Colour swatch (tap → small popover with 8 preset colours + a palette tile that opens the system colour picker)
   - Spacer
   - Undo
   - Redo
   - Active tool gets a gold (`#C9A227`) background; others get a faint white overlay
4. **Canvas** — fills all remaining space:
   - `PKCanvasView`, `drawingPolicy = .pencilOnly`
   - Dot-grid background, edge-to-edge, drawn via custom `UIView` behind the canvas
   - Dot colour: `#E5E5E0` (light) / `#2A2A35` (dark), 24pt spacing
5. **System `PKToolPicker` is hidden** — we drive the tool selection ourselves via the top tool row. Apple supports this (`PKToolPicker.setVisible(false, forFirstResponder:)`).

Reopening a saved sketch loads its `PKDrawing` and behaves identically. On Save, the **Replace / Append / Skip OCR** prompt from V6 fires.

On iPhone, the Sketch button on the note editor remains disabled (per V6 spec). This view is only ever presented on iPad.

### Note editor (per V6 spec, polished for iPad in V7)

Layout when `idiom == .pad`:

- **App bar** with Back / Notes title / Edit-Preview toggle (existing, slightly bigger touch targets)
- **Meta row** under bar (smaller caption: session title · date · time)
- **Editor body**: single column, max-width 640pt, centred, comfortable padding (28pt sides)
- **Bottom media strip**: persistent, replaces the current scattered photo strip:
  - Two action buttons on the left: `+ Sketch` (navy, gold icon) and `+ Photo` (teal)
  - Horizontal scroll of existing media thumbnails (sketches and photos mixed, in chronological order)
  - Tap a thumbnail → reopen sketch in canvas / view photo in lightbox / delete via long-press menu
- Strip respects keyboard: when keyboard appears, strip slides up to sit immediately above the keyboard

On iPhone, existing layout retained.

### Schedule / Search / My Picks / Extras tabs

Light polish only. For each on iPad:

- **Cards / list rows**: max-width 720pt, centred. Content density stays similar but with more breathing room.
- **Section headers**: bigger type, more vertical space.
- **Hit targets**: 44pt minimum (already true on iPhone, just verify after layout changes).

No structural changes. No content changes.

## Implementation Sketch

### New files

| File | Purpose |
|---|---|
| `ConferenceNav/Design/IdiomLayout.swift` | `UIUserInterfaceIdiom.isPad` helper + iPad-specific tokens (max widths, spacing scale, type sizes) |
| `ConferenceNav/Views/SketchEditor/SketchEditorView.swift` | Full-screen editor (the V6 main view, designed per V7) |
| `ConferenceNav/Views/SketchEditor/SketchToolbar.swift` | Top tool row with pen/pencil/marker/eraser/colour/undo/redo |
| `ConferenceNav/Views/SketchEditor/PKCanvasRepresentable.swift` | `UIViewRepresentable` wrapping `PKCanvasView` |
| `ConferenceNav/Views/SketchEditor/DotGridBackgroundView.swift` | Dot-grid `UIView` drawn behind the canvas |
| `ConferenceNav/Views/Components/MediaStrip.swift` | Bottom strip used by the iPad note editor — `+ Sketch` / `+ Photo` / thumbnails |
| `ConferenceNav/Views/Components/ReaderModeFigure.swift` | Inline figure component with caption rendering |

### Modified files

| File | Change |
|---|---|
| `ConferenceNav/Views/SessionDetailView.swift` | Branch on `isPad` for reader-mode container, typography, figure rendering |
| `ConferenceNav/Views/NoteEditorView.swift` | Branch on `isPad` for max-width content + bottom MediaStrip |
| `ConferenceNav/Views/ScheduleView.swift` | iPad: max-width container, larger section headers |
| `ConferenceNav/Views/SearchView.swift` | iPad: max-width container |
| `ConferenceNav/Views/MyPicksView.swift` | iPad: max-width container |
| `ConferenceNav/Views/ExtrasView.swift` | iPad: max-width container |
| `ConferenceNav/Design/ConferenceDesign.swift` | New iPad-tuned font sizes (e.g. `CNFonts.iPadHeadline`); existing iPhone tokens unchanged |
| `ConferenceNav/Design/MarkdownTheme.swift` | iPad branch for body type size + line height; figure styling for inline images |

### Max-width values (intentional differences)

| View | iPad max-width | Why |
|---|---|---|
| Session detail (reader mode) | 600pt | Tight column for prose readability; matches typesetting conventions for ~70-character lines at 18pt serif |
| Note editor body | 640pt | Same prose reasoning, slightly wider to accommodate Markdown formatting + monospace font |
| Schedule / Search / My Picks / Extras | 720pt | Dense card/list content; needs more horizontal space for cards with badges, times, venues, and B/R indicators |
| Sketch editor canvas | full-bleed | No max-width — drawing surface fills available space |
| App bar / tool row | full-bleed | Spans entire screen width regardless of underlying content max-width |

### Layout strategy

We don't fork view files. Each affected view has a `body` that branches on `isPad` either:
- **Inline conditional** for small differences (e.g. padding, type size)
- **`.frame(maxWidth:)` modifier** chained onto existing content for max-width containers
- **`if #if isPad ... else ... #endif`** *not* used — we want runtime branching so the universal binary serves both correctly

Example (Schedule):

```swift
List(sessions) { session in
    SessionRow(session: session)
}
.frame(maxWidth: UIUserInterfaceIdiom.isPad ? 720 : .infinity)
.frame(maxWidth: .infinity, alignment: .center)
```

### PKToolPicker integration

```swift
let canvas = PKCanvasView()
canvas.drawingPolicy = .pencilOnly
canvas.becomeFirstResponder()

if let toolPicker = PKToolPicker.shared(for: window) {
    toolPicker.setVisible(false, forFirstResponder: canvas)
    toolPicker.removeObserver(canvas)
}

// Drive tool selection from custom toolbar:
canvas.tool = PKInkingTool(.pen, color: selectedColor, width: selectedWidth)
```

The shared system picker stays in memory (used by other apps) but isn't shown for our canvas.

### Dot-grid background

A custom `UIView` placed behind the `PKCanvasView` (which is transparent by default). Override `draw(_:)` to render the dot pattern with `CGContext` using `UIColor` from the design tokens. Spacing 24pt, dot radius 1pt. Dark mode automatic via `traitCollection.userInterfaceStyle`.

The grid does not pan/zoom with the canvas — it's a static background per page (PencilKit sketches in this app are single-page; no infinite canvas).

### Reader-mode figure rendering

When MarkdownUI renders the body, we register a custom inline-image renderer that wraps `<img>` in a figure container:

```swift
.markdownImageProvider(ReaderModeImageProvider(notesStore: notesStore))
```

The provider returns a SwiftUI view: `VStack { Image; if let caption { Text(caption).italic().font(.caption).foregroundStyle(.secondary) } }` where `caption` comes from the next paragraph if it's short prose. Long paragraphs are *not* treated as captions — only ≤100-char paragraphs that immediately follow an image.

## Edge Cases

- **App launches on iPad in compatibility mode after upgrade.** Idiom is correctly detected; iPad layouts apply on first run. No migration needed.
- **User rotates iPad mini to landscape.** Layout still works (max-width centre is robust). We don't optimise but we don't break.
- **Sketch saved on iPad, viewed on iPhone via iCloud sync.** Renders fine — sketch is a PNG, treated like any other inline image. Just smaller.
- **Existing sketches with no caption paragraph after them.** Figure renders without caption — no empty caption space.
- **iPad mini in dark mode at midnight in Prague.** Dot grid uses dark-mode token, canvas is dark, ink defaults to white pen. Verified in design tokens.
- **PKToolPicker observers leak between presentations.** Cleanup in `onDisappear` removes the observer if any was added.
- **Very long session title in sketch editor app bar.** Truncates with ellipsis after 1 line; full title is in note context underneath.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| iPad layout regressions to iPhone experience for Ron | Medium | High | All iPad code is gated on `isPad`. Run iPhone build on simulator after every iPad-affecting change. Test the iPhone build path explicitly before committing. |
| Custom toolbar misses a PencilKit feature Ben wants (e.g. ruler) | Low | Low | Initial release: pen/pencil/marker/eraser/colour/undo/redo. If Ben wants ruler post-conference, easy to add later. |
| MarkdownUI's image provider API doesn't expose enough control for figure layout | Low | Medium | Tested before locking — fallback is to manually parse `![]()` references in the body and render them ourselves. |
| 11-day timeline is tight | Medium | High | V7 is genuinely scoped down — no sidebar, no landscape-tuning, no Pro-tuning, no Handoff. Polish + reader mode + sketch UI = bounded surface area. |
| Compatibility-mode users (no iPad in our test pool) | Low | Low | Ben can test on his iPad mini before TestFlight push. No other iPad users. |

## Testing Plan

- **iPhone (regression)**: every existing flow works identically. Schedule scrolls, Search filters, My Picks toggles, Extras navigates. Notes save and export. PDF export works (V6).
- **iPad mini portrait (primary)**:
  - Each tab loads with iPad-polished proportions
  - Session detail shows reader-mode typography and inline figures
  - Note editor shows single column with bottom MediaStrip
  - Sketch editor opens full-screen with custom top toolbar; Pencil draws; finger does not draw; tools switch correctly; colour picker works; undo/redo works
  - Save → OCR → dismiss back to note editor with `![sketch](...)` inserted at cursor
  - Reopening a saved sketch loads its `PKDrawing` and shows the Replace/Append/Skip OCR prompt
- **iPad mini landscape**: layouts don't break; reader mode still readable; sketch editor still usable.
- **iCloud sync**: sketch created on iPad, photo from iPhone, both appear on the other device after sync.

## Sequencing with V6

V6 ships first as a vertical slice (Pencil + OCR + PDF), V7 polishes layouts on top. But because the V6 sketch editor is *inherently iPad-only*, we'll actually build:

1. V6 sketch editor with the V7 layout (top toolbar, dot grid, fill-screen) — they're the same view
2. V6 PDF export (no UI changes needed)
3. V6 note editor sketch button + media strip
4. V7 reader-mode session detail
5. V7 tab polish (Schedule / Search / My Picks / Extras max-width containers)
6. V7 final iPhone-regression sweep

The implementation plan will sequence these as one combined work order rather than two separate releases.
