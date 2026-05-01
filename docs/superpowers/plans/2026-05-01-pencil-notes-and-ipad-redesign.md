# V6 + V7 Implementation Plan — Pencil Notes & iPad-First Redesign

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Apple Pencil sketch capture (with on-device OCR), PDF export with TOC, and iPad-native layouts for the EAPragueC 2026 conference app — all before Ben flies to Prague on 12 May 2026.

**Architecture:** Single combined work order. iPad-only behaviour gated on `UIUserInterfaceIdiom.isPad` so iPhone (Ron) doesn't regress. Sketches stored as `PKDrawing` + rendered PNG pairs in iCloud Drive Documents/Notes/sketches/, referenced inline in note Markdown. PDF export via Markdown → HTML → `WKWebView.createPDF`. No new external dependencies — only Apple frameworks (PencilKit, Vision, WebKit).

**Tech Stack:** SwiftUI · UIKit (PencilKit, WebKit) · Vision framework · MarkdownUI (existing) · xcodegen · iCloud Drive ubiquity · Swift 5.9 · iOS 17+.

**Specs:**
- [V6 — Pencil Notes & PDF Export](../specs/2026-05-01-pencil-notes-pdf-export-design.md)
- [V7 — iPad-First Redesign](../specs/2026-05-01-ipad-first-redesign-design.md)

**Verification approach:** No formal XCTest target exists; we won't add one for this timeline. Verification is via SwiftUI Previews + simulator runs + Ben's iPad mini for the sketch-specific flows. Data-model serialisation (SessionNote round-trip with sketches) gets a debug round-trip assertion in a `#if DEBUG` preview.

---

## File Structure

### New files

```
ConferenceNav/
├── Design/
│   └── IdiomLayout.swift                      ← isPad helper + iPad tokens
├── Services/
│   ├── SketchOCRService.swift                 ← Vision OCR wrapper
│   └── PDFExportService.swift                 ← Markdown → HTML → PDF
├── Views/
│   ├── SketchEditor/
│   │   ├── SketchEditorView.swift             ← Full-screen editor (top-level)
│   │   ├── SketchToolbar.swift                ← Custom top tool row
│   │   ├── PKCanvasRepresentable.swift        ← UIViewRepresentable for PKCanvasView
│   │   └── DotGridBackgroundView.swift        ← Dot-grid behind canvas
│   └── Components/
│       ├── MediaStrip.swift                   ← Bottom strip in iPad note editor
│       └── ReaderModeFigure.swift             ← Inline figure in iPad reader mode
└── Resources/
    └── report.css                              ← CSS for PDF export HTML
```

### Modified files

```
ConferenceNav/
├── Models/
│   └── SessionNote.swift                      ← + sketchFilenames + YAML
├── Services/
│   └── NotesStore.swift                        ← sketch CRUD, sketchURL(), allMediaFilenames
├── Views/
│   ├── NoteEditorView.swift                    ← Sketch button + MediaStrip + iPad branch
│   ├── ExportView.swift                        ← PDF rows
│   ├── SessionDetailView.swift                 ← iPad reader-mode branch
│   ├── ScheduleView.swift                      ← iPad max-width
│   ├── SearchView.swift                        ← iPad max-width
│   ├── MyPicksView.swift                       ← iPad max-width
│   └── ExtrasView.swift                        ← iPad max-width
├── Design/
│   ├── ConferenceDesign.swift                  ← iPad font tokens
│   └── MarkdownTheme.swift                     ← iPad branch + figure provider
└── project.yml                                 ← regenerate after source additions
```

### Phase ordering

1. **Phase 1 — Foundations** (Tasks 1–2): IdiomLayout helper + SessionNote data model
2. **Phase 2 — Sketch Editor** (Tasks 3–7): the V6/V7 sketch surface
3. **Phase 3 — OCR** (Tasks 8–9): Vision integration
4. **Phase 4 — Note Editor** (Tasks 10–11): MediaStrip + iPad note layout
5. **Phase 5 — Reader Mode** (Tasks 12–13): SessionDetailView iPad polish
6. **Phase 6 — PDF Export** (Tasks 14–16): the printable artefact
7. **Phase 7 — Tab Polish** (Task 17): max-width on Schedule/Search/My Picks/Extras
8. **Phase 8 — Verification** (Tasks 18–19): regression sweep + Ben's iPad walkthrough

---

## Phase 1 — Foundations

### Task 1: IdiomLayout helper + iPad design tokens

**Files:**
- Create: `ConferenceNav/Design/IdiomLayout.swift`
- Modify: `ConferenceNav/Design/ConferenceDesign.swift`

- [ ] **Step 1: Create IdiomLayout.swift**

```swift
import SwiftUI
import UIKit

enum CNLayout {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    enum MaxWidth {
        static let readerBody: CGFloat = 600
        static let noteEditor: CGFloat = 640
        static let tabContent: CGFloat = 720
    }

    enum Spacing {
        static var screenHorizontal: CGFloat { isPad ? 28 : 16 }
        static var sectionVertical: CGFloat { isPad ? 24 : 16 }
        static var cardPadding: CGFloat { isPad ? 18 : 12 }
    }
}

extension View {
    /// Centres content with a max-width on iPad; full-bleed on iPhone.
    func cnPadMaxWidth(_ width: CGFloat) -> some View {
        self
            .frame(maxWidth: CNLayout.isPad ? width : .infinity)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
```

- [ ] **Step 2: Add iPad font tokens to ConferenceDesign.swift**

Open the file and locate `enum CNFonts`. Add inside that enum (preserving existing tokens):

```swift
// iPad-tuned variants — fall back to phone tokens on iPhone
static var readerHeadline: Font {
    CNLayout.isPad
        ? .custom("New York", size: 32).weight(.medium)
        : title
}
static var readerBody: Font {
    CNLayout.isPad
        ? .custom("New York", size: 18)
        : body
}
static var readerCaption: Font {
    CNLayout.isPad
        ? .custom("New York", size: 13).italic()
        : caption.italic()
}
static var readerMeta: Font {
    .system(size: CNLayout.isPad ? 11 : 10, weight: .regular, design: .default)
}
```

If `New York` fontName resolves to nil on the device, SwiftUI falls back to system serif gracefully. No fallback handling required.

- [ ] **Step 3: Regenerate Xcode project**

Run: `cd /Users/andiyar/Developer/WheresBen/ConferenceNav && xcodegen generate`
Expected: "Generated project successfully"

- [ ] **Step 4: Build to verify**

Open ConferenceNav.xcodeproj in Xcode → Build (⌘B). Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add ConferenceNav/Design/IdiomLayout.swift ConferenceNav/Design/ConferenceDesign.swift ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat(design): add IdiomLayout helper + iPad font tokens

Foundations for V7 iPad-first layouts. Gated behind CNLayout.isPad
so iPhone tokens are unchanged. cnPadMaxWidth() modifier centres
content with a max-width on iPad, full-bleed on iPhone."
```

---

### Task 2: SessionNote — add sketchFilenames

**Files:**
- Modify: `ConferenceNav/Models/SessionNote.swift`

- [ ] **Step 1: Add the property + init parameter**

In `SessionNote`, after `var photoFilenames: [String]` (around line 14):

```swift
var sketchFilenames: [String] // Relative filenames in sketches/ dir
```

Update the `init` to accept `sketchFilenames: [String] = []` after the existing `photoFilenames` parameter, and assign `self.sketchFilenames = sketchFilenames` in the body.

- [ ] **Step 2: Extend YAML serialisation in `toMarkdown()`**

After the existing photos block (around line 89), before `last_modified`:

```swift
if !sketchFilenames.isEmpty {
    md += "sketches:\n"
    for sketch in sketchFilenames {
        md += "  - \(sketch)\n"
    }
}
```

- [ ] **Step 3: Extend YAML parsing in `fromMarkdown()`**

In the YAML parser (around line 110-130), add a `var sketches: [String] = []` and a `var inSketches = false` alongside the existing photo parser. The parser flow:

```swift
var photos: [String] = []
var sketches: [String] = []
var inPhotos = false
var inSketches = false

for line in yamlBlock.components(separatedBy: "\n") {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { continue }

    if trimmed.hasPrefix("- ") {
        if inPhotos { photos.append(String(trimmed.dropFirst(2))); continue }
        if inSketches { sketches.append(String(trimmed.dropFirst(2))); continue }
    }
    inPhotos = false
    inSketches = false

    if let colonIndex = trimmed.firstIndex(of: ":") {
        let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

        if key == "photos" { inPhotos = true; continue }
        if key == "sketches" { inSketches = true; continue }
        yaml[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
```

Then pass `sketchFilenames: sketches` into the `SessionNote(...)` constructor at the end of the function.

- [ ] **Step 4: Update `hasNote(forPresentation:)` and `hasNote(forSession:)`**

Around lines 53-64, the existing has-content checks should also consider sketches. Replace both occurrences of:

```swift
return !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.photoFilenames.isEmpty
```

with:

```swift
return !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    || !note.photoFilenames.isEmpty
    || !note.sketchFilenames.isEmpty
```

Same change applies to `hasAnyNote(forSession:)`.

- [ ] **Step 5: Add a debug round-trip preview**

At the bottom of `SessionNote.swift`:

```swift
#if DEBUG
struct SessionNoteRoundTripPreview: View {
    var body: some View {
        let original = SessionNote(
            sessionId: 42,
            sessionTitle: "Test Session",
            sessionDate: "2026-05-15",
            sessionTime: "10:00-11:00",
            sessionVenue: "C1",
            body: "Some notes\n\n![sketch](sketches/abc.png)\n\nCaption",
            photoFilenames: ["a.jpg"],
            sketchFilenames: ["abc.png"]
        )
        let md = original.toMarkdown()
        let parsed = SessionNote.fromMarkdown(md)
        return VStack(alignment: .leading) {
            Text("Original sketches: \(original.sketchFilenames.joined(separator: ","))")
            Text("Parsed sketches:   \(parsed?.sketchFilenames.joined(separator: ",") ?? "nil")")
            Text("Match: \(original.sketchFilenames == parsed?.sketchFilenames ? "✅" : "❌")")
        }
        .padding()
    }
}

#Preview { SessionNoteRoundTripPreview() }
#endif
```

This requires `import SwiftUI` at the top (verify it's there; if not, add it).

- [ ] **Step 6: Build and run the preview**

Open `SessionNote.swift` in Xcode → Canvas (⌥⌘↵) → expect "Match: ✅".

- [ ] **Step 7: Commit**

```bash
git add ConferenceNav/Models/SessionNote.swift
git commit -m "feat(notes): add sketchFilenames to SessionNote with YAML serialisation

Sketches stored as a parallel array to photoFilenames. Same YAML pattern
under a 'sketches:' block. has-content checks now consider sketches.
Debug round-trip preview verifies serialisation."
```

---

## Phase 2 — Sketch Editor

### Task 3: PKCanvasRepresentable

**Files:**
- Create: `ConferenceNav/Views/SketchEditor/PKCanvasRepresentable.swift`

- [ ] **Step 1: Create the SwiftUI wrapper**

```swift
import SwiftUI
import PencilKit

struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var tool: PKTool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawing = drawing
        canvas.tool = tool
        canvas.delegate = context.coordinator

        // Hide the system tool picker — we drive tool selection from our top toolbar
        DispatchQueue.main.async {
            if let window = canvas.window,
               let toolPicker = PKToolPicker.shared(for: window) {
                toolPicker.setVisible(false, forFirstResponder: canvas)
                toolPicker.removeObserver(canvas)
            }
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
        canvas.tool = tool
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PKCanvasRepresentable
        init(_ parent: PKCanvasRepresentable) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
```

- [ ] **Step 2: Build to verify**

⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SketchEditor/PKCanvasRepresentable.swift
git commit -m "feat(sketch): add PKCanvasRepresentable SwiftUI wrapper

Wraps PKCanvasView with bindings for drawing + tool. Pencil-only.
System tool picker hidden — tool selection driven by our custom toolbar."
```

---

### Task 4: DotGridBackgroundView

**Files:**
- Create: `ConferenceNav/Views/SketchEditor/DotGridBackgroundView.swift`

- [ ] **Step 1: Create the dot-grid background**

```swift
import SwiftUI
import UIKit

struct DotGridBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> DotGridUIView { DotGridUIView() }
    func updateUIView(_ uiView: DotGridUIView, context: Context) { uiView.setNeedsDisplay() }
}

final class DotGridUIView: UIView {
    private let spacing: CGFloat = 24
    private let dotRadius: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let isDark = traitCollection.userInterfaceStyle == .dark
        let dotColor = isDark ? UIColor(white: 1.0, alpha: 0.16) : UIColor(red: 0.90, green: 0.90, blue: 0.88, alpha: 1.0)
        ctx.setFillColor(dotColor.cgColor)

        var y: CGFloat = spacing / 2
        while y < rect.height {
            var x: CGFloat = spacing / 2
            while x < rect.width {
                let dot = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                ctx.fillEllipse(in: dot)
                x += spacing
            }
            y += spacing
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }
}

#Preview {
    DotGridBackground()
        .frame(width: 400, height: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
}
```

- [ ] **Step 2: Verify in canvas**

Open in Xcode → Canvas → expect to see a faint dot-grid pattern.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SketchEditor/DotGridBackgroundView.swift
git commit -m "feat(sketch): add DotGridBackground for sketch canvas

24pt grid spacing, dark-mode aware via traitCollectionDidChange.
Used as background behind transparent PKCanvasView."
```

---

### Task 5: SketchToolbar

**Files:**
- Create: `ConferenceNav/Views/SketchEditor/SketchToolbar.swift`

- [ ] **Step 1: Define the tool model + colour palette**

```swift
import SwiftUI
import PencilKit

enum SketchToolKind: Hashable {
    case pen, pencil, marker, eraser

    var inkType: PKInkingTool.InkType? {
        switch self {
        case .pen: return .pen
        case .pencil: return .pencil
        case .marker: return .marker
        case .eraser: return nil
        }
    }

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .eraser: return "eraser.fill"
        }
    }
}

struct SketchToolbar: View {
    @Binding var selectedTool: SketchToolKind
    @Binding var selectedColor: Color
    let onUndo: () -> Void
    let onRedo: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var showingColorPalette = false

    private let palette: [Color] = [
        Color(red: 0.0, green: 0.15, blue: 0.39),    // navy
        Color(red: 0.85, green: 0.08, blue: 0.23),   // red
        Color(red: 0.79, green: 0.64, blue: 0.16),   // gold
        Color(red: 0.11, green: 0.42, blue: 0.49),   // teal
        Color.black,
        Color(red: 0.4, green: 0.4, blue: 0.4),      // grey
        Color(red: 0.45, green: 0.10, blue: 0.55),   // purple
        Color(red: 0.2, green: 0.55, blue: 0.2),     // green
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach([SketchToolKind.pen, .pencil, .marker, .eraser], id: \.self) { kind in
                toolButton(kind: kind)
            }

            Button { showingColorPalette = true } label: {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .padding(6)
            }
            .popover(isPresented: $showingColorPalette) {
                paletteView()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.0, green: 0.10, blue: 0.27))
    }

    @ViewBuilder
    private func toolButton(kind: SketchToolKind) -> some View {
        let isActive = selectedTool == kind
        Button { selectedTool = kind } label: {
            Image(systemName: kind.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? Color(red: 0.0, green: 0.15, blue: 0.39) : .white)
                .frame(width: 36, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color(red: 0.79, green: 0.64, blue: 0.16) : Color.white.opacity(0.08))
                )
        }
    }

    private func paletteView() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 4), spacing: 8) {
            ForEach(palette, id: \.self) { color in
                Button {
                    selectedColor = color
                    showingColorPalette = false
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .padding(12)
    }
}

#Preview {
    @Previewable @State var tool: SketchToolKind = .pen
    @Previewable @State var color: Color = Color(red: 0.0, green: 0.15, blue: 0.39)
    return SketchToolbar(
        selectedTool: $tool,
        selectedColor: $color,
        onUndo: {},
        onRedo: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
```

- [ ] **Step 2: Build and check preview**

⌘B then open canvas. Expected: toolbar with 4 tools + colour swatch + undo/redo on a navy background. Tap pencil → highlights gold.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SketchEditor/SketchToolbar.swift
git commit -m "feat(sketch): add custom top toolbar with pen/pencil/marker/eraser/color/undo/redo

Replaces system PKToolPicker with our own row at the top of the sketch
editor. 8-colour palette popover. Active tool highlighted in conference gold."
```

---

### Task 6: SketchEditorView

**Files:**
- Create: `ConferenceNav/Views/SketchEditor/SketchEditorView.swift`

- [ ] **Step 1: Compose the full editor**

```swift
import SwiftUI
import PencilKit

struct SketchEditorView: View {
    let sessionTitle: String
    let initialDrawing: PKDrawing
    let onCancel: () -> Void
    let onSave: (PKDrawing, UIImage) -> Void

    @State private var drawing: PKDrawing
    @State private var tool: PKTool = PKInkingTool(.pen, color: UIColor(red: 0, green: 0.15, blue: 0.39, alpha: 1), width: 2)
    @State private var selectedToolKind: SketchToolKind = .pen
    @State private var selectedColor: Color = Color(red: 0, green: 0.15, blue: 0.39)
    @State private var canvasView = PKCanvasView()

    init(
        sessionTitle: String,
        initialDrawing: PKDrawing = PKDrawing(),
        onCancel: @escaping () -> Void,
        onSave: @escaping (PKDrawing, UIImage) -> Void
    ) {
        self.sessionTitle = sessionTitle
        self.initialDrawing = initialDrawing
        self.onCancel = onCancel
        self.onSave = onSave
        self._drawing = State(initialValue: initialDrawing)
    }

    var body: some View {
        VStack(spacing: 0) {
            appBar
            SketchToolbar(
                selectedTool: $selectedToolKind,
                selectedColor: $selectedColor,
                onUndo: { canvasView.undoManager?.undo() },
                onRedo: { canvasView.undoManager?.redo() }
            )
            ZStack {
                DotGridBackground()
                CanvasContainer(canvas: $canvasView, drawing: $drawing, tool: $tool)
            }
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedToolKind) { _, _ in updateTool() }
        .onChange(of: selectedColor) { _, _ in updateTool() }
        .onAppear { updateTool() }
    }

    private var appBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .foregroundStyle(.white)
            Spacer()
            Text(sessionTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button {
                let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
                onSave(canvasView.drawing, image)
            } label: {
                Text("Save").fontWeight(.semibold).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0, green: 0.15, blue: 0.39))
    }

    private func updateTool() {
        let uiColor = UIColor(selectedColor)
        switch selectedToolKind {
        case .pen:    tool = PKInkingTool(.pen, color: uiColor, width: 2)
        case .pencil: tool = PKInkingTool(.pencil, color: uiColor, width: 2)
        case .marker: tool = PKInkingTool(.marker, color: uiColor, width: 8)
        case .eraser: tool = PKEraserTool(.vector)
        }
    }
}

private struct CanvasContainer: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var drawing: PKDrawing
    @Binding var tool: PKTool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawing = drawing
        canvas.tool = tool
        canvas.delegate = context.coordinator
        DispatchQueue.main.async {
            if let window = canvas.window,
               let toolPicker = PKToolPicker.shared(for: window) {
                toolPicker.setVisible(false, forFirstResponder: canvas)
                toolPicker.removeObserver(canvas)
            }
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.tool = tool
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: CanvasContainer
        init(_ parent: CanvasContainer) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

#Preview {
    SketchEditorView(
        sessionTitle: "SILENCE Trial Talk",
        onCancel: {},
        onSave: { _, _ in }
    )
}
```

Note: this supersedes Task 3's standalone `PKCanvasRepresentable.swift`. **Delete that file** if its contents have been replaced by `CanvasContainer` here, OR keep `PKCanvasRepresentable.swift` and have `SketchEditorView` use it instead. Choose the latter to keep separation. Replace the inline `CanvasContainer` with:

```swift
PKCanvasRepresentable(drawing: $drawing, tool: $tool)
    .background(GeometryReader { _ in Color.clear })
```

But because we need access to the actual `PKCanvasView` instance (for undo/redo and image rendering), we keep `CanvasContainer` here as the canonical implementation and **delete `PKCanvasRepresentable.swift`** in this task.

Actually, simpler — in **Step 1.5** below — delete the file from Task 3 since this view absorbs it.

- [ ] **Step 1.5: Delete the redundant PKCanvasRepresentable.swift**

```bash
rm ConferenceNav/Views/SketchEditor/PKCanvasRepresentable.swift
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
cd /Users/andiyar/Developer/WheresBen/ConferenceNav && xcodegen generate
```

- [ ] **Step 3: Build and run on iPad simulator**

Build → run on iPad mini (6th gen) simulator → preview the view from a debug menu (or wire it temporarily to the note editor's button — but that's Task 11). For now, use the SwiftUI Preview.

Expected: full-screen sketch UI; tapping tool buttons changes the active tool; with Pencil simulator (or trackpad as Pencil) you can draw.

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/Views/SketchEditor/ ConferenceNav/ConferenceNav.xcodeproj
git rm ConferenceNav/Views/SketchEditor/PKCanvasRepresentable.swift 2>/dev/null || true
git commit -m "feat(sketch): SketchEditorView composing toolbar + canvas + dot grid

Top app bar (Cancel/title/Save), tool row, full-bleed dot-grid canvas.
Pen/pencil/marker/eraser tools wired to PKCanvasView. Save renders
the drawing to a UIImage and passes both PKDrawing + UIImage to caller."
```

---

### Task 7: Sketch persistence in NotesStore

**Files:**
- Modify: `ConferenceNav/Services/NotesStore.swift`

- [ ] **Step 1: Add sketches directory helper + sketch URL accessor**

In NotesStore, near `photosDirectory()` (around line 240):

```swift
private func sketchesDirectory() -> URL {
    let base = containerURL()
    return base.appendingPathComponent("sketches")
}

func sketchURL(filename: String) -> URL? {
    let url = sketchesDirectory().appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
}

func sketchDrawingURL(forImageFilename pngFilename: String) -> URL? {
    let stem = (pngFilename as NSString).deletingPathExtension
    let url = sketchesDirectory().appendingPathComponent("\(stem).drawing")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
}
```

- [ ] **Step 2: Add saveSketch() method**

```swift
import PencilKit

// ... within NotesStore class:

/// Saves a sketch — both the editable PKDrawing data and a rendered PNG.
/// Returns the relative filename of the PNG (for embedding in note body).
func saveSketch(drawing: PKDrawing, image: UIImage) -> String? {
    let stem = UUID().uuidString
    let pngName = "\(stem).png"
    let drawingName = "\(stem).drawing"
    let dir = sketchesDirectory()

    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let pngData = image.pngData() {
            try pngData.write(to: dir.appendingPathComponent(pngName))
        }
        try drawing.dataRepresentation().write(to: dir.appendingPathComponent(drawingName))
        return pngName
    } catch {
        print("NotesStore: Failed to save sketch: \(error)")
        return nil
    }
}

func loadSketchDrawing(filename pngFilename: String) -> PKDrawing? {
    guard let url = sketchDrawingURL(forImageFilename: pngFilename) else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? PKDrawing(data: data)
}

func deleteSketch(filename pngFilename: String) {
    let dir = sketchesDirectory()
    let stem = (pngFilename as NSString).deletingPathExtension
    try? FileManager.default.removeItem(at: dir.appendingPathComponent(pngFilename))
    try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(stem).drawing"))
}

/// Combined media filenames (photos + sketches) for export
var allMediaFilenames: [String] {
    notes.flatMap { $0.photoFilenames + $0.sketchFilenames }
}

func sketchOrPhotoURL(filename: String) -> URL? {
    photoURL(filename: filename) ?? sketchURL(filename: filename)
}
```

Add `import PencilKit` at the top of the file if not present.

Note: existing call sites use `allPhotoFilenames` (per ExportView.swift). Keep that property intact and add `allMediaFilenames` as the new combined accessor — Task 11 (note editor) and Task 16 (PDF export) will switch consumers over.

- [ ] **Step 3: Build to verify**

⌘B. Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/Services/NotesStore.swift
git commit -m "feat(notes): add sketch persistence in NotesStore

Saves both PKDrawing data (.drawing) and rendered PNG to
notes/sketches/{uuid}.{png,drawing}. Adds load/delete/URL helpers
and combined allMediaFilenames accessor."
```

---

## Phase 3 — Vision OCR

### Task 8: SketchOCRService

**Files:**
- Create: `ConferenceNav/Services/SketchOCRService.swift`

- [ ] **Step 1: Create the service**

```swift
import Foundation
import Vision
import UIKit

enum SketchOCR {
    /// Runs Vision text recognition over the image and returns concatenated text.
    /// Returns nil if recognition fails or produces no text.
    static func transcribe(image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("SketchOCR: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sort by reading order: top-to-bottom, left-to-right.
                // Vision returns normalized coordinates with origin at bottom-left,
                // so larger y means higher on the page — sort y descending.
                let sorted = observations.sorted { a, b in
                    let aTop = a.boundingBox.maxY
                    let bTop = b.boundingBox.maxY
                    if abs(aTop - bTop) > 0.04 { return aTop > bTop }   // different lines
                    return a.boundingBox.minX < b.boundingBox.minX       // same line, left-to-right
                }

                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                let combined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: combined.isEmpty ? nil : combined)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-GB", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("SketchOCR: handler failed \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

⌘B. Expected: build succeeds (Vision is part of base SDK).

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Services/SketchOCRService.swift
git commit -m "feat(sketch): add SketchOCR service using Vision framework

VNRecognizeTextRequest at .accurate level with handwriting recognition.
Sorts observations into reading order (top-to-bottom, left-to-right).
Returns nil for empty/failed recognition."
```

---

### Task 9: Re-OCR prompt for reopened sketches

**Files:**
- Modify: `ConferenceNav/Views/SketchEditor/SketchEditorView.swift`

- [ ] **Step 1: Extend SketchEditorView Save flow with re-OCR prompt**

Replace the Save button action and the simple `onSave(drawing, image)` callback with a flow that emits an `OCRDecision` choice when the editor was opened with an existing drawing.

Change the `onSave` signature:

```swift
let onSave: (PKDrawing, UIImage, OCRDecision) -> Void
```

Add the enum (at top of file, outside the struct):

```swift
enum OCRDecision {
    case none           // first-time save → caller decides what to do (typically: run OCR)
    case replace        // re-save: replace existing transcription
    case append         // re-save: append new transcription
    case skip           // re-save: keep existing transcription, don't OCR again
}
```

Track whether this is a re-edit:

```swift
@State private var showOCRPrompt = false
private var isReedit: Bool { !initialDrawing.strokes.isEmpty }
```

Replace the Save button body:

```swift
Button {
    if isReedit {
        showOCRPrompt = true
    } else {
        save(decision: .none)
    }
} label: {
    Text("Save").fontWeight(.semibold).foregroundStyle(.white)
}
```

Add `save(decision:)`:

```swift
private func save(decision: OCRDecision) {
    let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
    onSave(canvasView.drawing, image, decision)
}
```

Add the confirmation dialog at the top level of `body`:

```swift
.confirmationDialog(
    "Sketch updated — what about the transcription?",
    isPresented: $showOCRPrompt,
    titleVisibility: .visible
) {
    Button("Replace existing transcription") { save(decision: .replace) }
    Button("Append new transcription") { save(decision: .append) }
    Button("Skip OCR (keep transcription as-is)") { save(decision: .skip) }
    Button("Cancel", role: .cancel) {}
}
```

Update the preview's `onSave` closure to take three params: `{ _, _, _ in }`.

- [ ] **Step 2: Build to verify**

⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SketchEditor/SketchEditorView.swift
git commit -m "feat(sketch): add re-OCR prompt when reopening a saved sketch

First save (empty initial drawing) goes straight through.
Re-saves prompt: Replace / Append / Skip OCR. Decision passed back
to caller so the note editor can mutate the body accordingly."
```

---

## Phase 4 — Note Editor

### Task 10: MediaStrip component

**Files:**
- Create: `ConferenceNav/Views/Components/MediaStrip.swift`

- [ ] **Step 1: Create the strip**

```swift
import SwiftUI

struct MediaStrip: View {
    let photoFilenames: [String]
    let sketchFilenames: [String]
    let onAddSketch: () -> Void
    let onAddPhoto: () -> Void
    let onTapMedia: (MediaItem) -> Void

    enum MediaItem: Hashable {
        case photo(filename: String)
        case sketch(filename: String)

        var filename: String {
            switch self {
            case .photo(let f), .sketch(let f): return f
            }
        }
    }

    @Environment(NotesStore.self) var notesStore

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAddSketch) {
                Label("Sketch", systemImage: "scribble.variable")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0, green: 0.15, blue: 0.39))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!CNLayout.isPad)
            .opacity(CNLayout.isPad ? 1 : 0.4)

            Button(action: onAddPhoto) {
                Label("Photo", systemImage: "photo")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.11, green: 0.42, blue: 0.49))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sketchFilenames, id: \.self) { f in
                        thumbnail(for: .sketch(filename: f))
                    }
                    ForEach(photoFilenames, id: \.self) { f in
                        thumbnail(for: .photo(filename: f))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    @ViewBuilder
    private func thumbnail(for item: MediaItem) -> some View {
        Button { onTapMedia(item) } label: {
            ZStack {
                if let url = thumbnailURL(for: item),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: item.iconName)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func thumbnailURL(for item: MediaItem) -> URL? {
        switch item {
        case .photo(let f): return notesStore.photoURL(filename: f)
        case .sketch(let f): return notesStore.sketchURL(filename: f)
        }
    }
}

private extension MediaStrip.MediaItem {
    var iconName: String {
        switch self {
        case .photo: return "photo"
        case .sketch: return "scribble.variable"
        }
    }
}
```

- [ ] **Step 2: Build to verify**

⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/Components/MediaStrip.swift
git commit -m "feat(notes): add MediaStrip component for iPad note editor

Bottom strip with + Sketch / + Photo buttons and horizontally-scrolling
thumbnails. Sketch button disabled on iPhone (Pencil-only feature).
Tap thumbnail emits MediaItem to caller for view/reopen flows."
```

---

### Task 11: Wire SketchEditor into NoteEditorView (with iPad branch)

**Files:**
- Modify: `ConferenceNav/Views/NoteEditorView.swift`

> **Approach:** Add the Sketch button + sheet presentation + body-mutation logic *unconditionally* on iPad. On iPhone, the existing layout stays exactly as is. The new code paths are gated on `CNLayout.isPad`.

- [ ] **Step 1: Read current NoteEditorView to find the right insertion points**

```bash
grep -n "var body\|NavigationStack\|toolbar\|Photo\|VStack" /Users/andiyar/Developer/WheresBen/ConferenceNav/Views/NoteEditorView.swift | head -30
```

Identify:
- Where the editor's TextEditor sits
- Where the existing photo button/sheet lives
- Where the bottom of the screen is for the iPad MediaStrip insertion

- [ ] **Step 2: Add @State and helpers near the top of the struct**

```swift
@State private var showSketchEditor = false
@State private var pendingSketchEdit: (filename: String, drawing: PKDrawing)?
```

Add `import PencilKit` at the top.

- [ ] **Step 3: Add the saveAndAppend / replaceTranscription helpers**

```swift
private func handleSketchSave(drawing: PKDrawing, image: UIImage, decision: OCRDecision) async {
    // Save sketch files
    guard let pngFilename = notesStore.saveSketch(drawing: drawing, image: image) else { return }

    if let existing = pendingSketchEdit {
        // Re-edit: delete the old files, the new ones replace them.
        notesStore.deleteSketch(filename: existing.filename)
        // Rewrite body image references from old → new filename
        note.body = note.body.replacingOccurrences(of: "sketches/\(existing.filename)", with: "sketches/\(pngFilename)")
        // Update the sketch list
        if let idx = note.sketchFilenames.firstIndex(of: existing.filename) {
            note.sketchFilenames[idx] = pngFilename
        }
    } else {
        // First-time save: append image reference + transcription to body
        note.sketchFilenames.append(pngFilename)
    }

    // Run OCR per decision
    let transcription: String? = await {
        switch decision {
        case .skip: return nil
        case .none, .replace, .append: return await SketchOCR.transcribe(image: image)
        }
    }()

    if pendingSketchEdit == nil {
        // First-time: append fresh block
        let block = "\n\n![sketch](sketches/\(pngFilename))\n\n\(transcription ?? "")\n"
        note.body += block
    } else if let t = transcription {
        switch decision {
        case .replace:
            // Replace the paragraph immediately following the image reference
            note.body = replaceTranscriptionAfterImage(filename: pngFilename, body: note.body, with: t)
        case .append:
            note.body = appendTranscriptionAfterImage(filename: pngFilename, body: note.body, with: t)
        case .skip, .none:
            break
        }
    }

    notesStore.save(note)
    pendingSketchEdit = nil
}

private func replaceTranscriptionAfterImage(filename: String, body: String, with text: String) -> String {
    let imgRef = "![sketch](sketches/\(filename))"
    guard let range = body.range(of: imgRef) else { return body }
    // Find the paragraph immediately after the image reference
    let afterImage = body[range.upperBound...]
    if let nextDoubleNewline = afterImage.range(of: "\n\n") {
        let captionEnd = afterImage[nextDoubleNewline.upperBound...].range(of: "\n\n")?.lowerBound
            ?? afterImage.endIndex
        let prefix = body[..<range.upperBound]
        let suffix = afterImage[captionEnd...]
        return "\(prefix)\n\n\(text)\(suffix)"
    }
    return body + "\n\n" + text
}

private func appendTranscriptionAfterImage(filename: String, body: String, with text: String) -> String {
    let imgRef = "![sketch](sketches/\(filename))"
    guard let range = body.range(of: imgRef) else { return body }
    let afterImage = body[range.upperBound...]
    if let nextDoubleNewline = afterImage.range(of: "\n\n") {
        let insertionIndex = afterImage[nextDoubleNewline.upperBound...].range(of: "\n\n")?.lowerBound
            ?? afterImage.endIndex
        let prefix = body[..<range.upperBound]
        let middle = afterImage[..<insertionIndex]
        let suffix = afterImage[insertionIndex...]
        return "\(prefix)\(middle) \(text)\(suffix)"
    }
    return body + "\n\n" + text
}
```

- [ ] **Step 4: Add the sheet presentation**

In the body, after the existing photo sheet:

```swift
.fullScreenCover(isPresented: $showSketchEditor) {
    SketchEditorView(
        sessionTitle: note.displayTitle,
        initialDrawing: pendingSketchEdit?.drawing ?? PKDrawing(),
        onCancel: {
            showSketchEditor = false
            pendingSketchEdit = nil
        },
        onSave: { drawing, image, decision in
            showSketchEditor = false
            Task { await handleSketchSave(drawing: drawing, image: image, decision: decision) }
        }
    )
}
```

- [ ] **Step 5: On iPad, render the MediaStrip below the editor**

Wrap the editor's main VStack in a conditional layout. On iPad, content area gets max-width 640, and the MediaStrip is appended:

```swift
VStack(spacing: 0) {
    // existing editor content (keep as-is)
    existingEditorContent
        .cnPadMaxWidth(CNLayout.MaxWidth.noteEditor)

    if CNLayout.isPad {
        MediaStrip(
            photoFilenames: note.photoFilenames,
            sketchFilenames: note.sketchFilenames,
            onAddSketch: { showSketchEditor = true },
            onAddPhoto: { /* trigger existing photo picker */ },
            onTapMedia: { item in
                switch item {
                case .photo: /* open photo lightbox (existing flow) */ break
                case .sketch(let f):
                    if let d = notesStore.loadSketchDrawing(filename: f) {
                        pendingSketchEdit = (filename: f, drawing: d)
                        showSketchEditor = true
                    }
                }
            }
        )
    }
}
```

Replace `existingEditorContent` with the actual existing layout (literal copy from the current file). The point is: keep iPhone layout untouched and add the MediaStrip *only* on iPad.

- [ ] **Step 6: Build and run on iPad simulator**

⌘B → run on iPad mini sim → open a note → Sketch button visible at bottom → tap → SketchEditorView appears full-screen.

- [ ] **Step 7: Commit**

```bash
git add ConferenceNav/Views/NoteEditorView.swift
git commit -m "feat(notes): wire SketchEditor into NoteEditorView with iPad MediaStrip

Sketch button (iPad only) presents full-screen SketchEditorView. On save,
runs OCR and inserts ![sketch](...) + transcription block in note body.
Reopen flow loads existing PKDrawing and prompts Replace/Append/Skip OCR.
iPhone layout unchanged."
```

---

## Phase 5 — Reader Mode

### Task 12: ReaderModeFigure component

**Files:**
- Create: `ConferenceNav/Views/Components/ReaderModeFigure.swift`

- [ ] **Step 1: Create the figure component**

```swift
import SwiftUI

struct ReaderModeFigure: View {
    let imageURL: URL?
    let caption: String?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = imageURL,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 480)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(Image(systemName: "photo"))
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(CNFonts.readerCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 2: Build to verify**

⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/Components/ReaderModeFigure.swift
git commit -m "feat(reader): add ReaderModeFigure for inline images on iPad

Image with subtle border + italic centred caption. Used by iPad reader-mode
session detail to render sketches and photos as proper inline figures."
```

---

### Task 13: SessionDetailView iPad reader mode

**Files:**
- Modify: `ConferenceNav/Views/SessionDetailView.swift`
- Modify: `ConferenceNav/Design/MarkdownTheme.swift`

- [ ] **Step 1: Add iPad branch to MarkdownTheme**

In `MarkdownTheme.swift`, find the body text style. Adapt sizes/families on iPad:

```swift
extension Theme {
    static var conference: Theme {
        Theme()
            .text {
                FontFamily(CNLayout.isPad ? "New York" : .system)
                FontSize(CNLayout.isPad ? 18 : 16)
                ForegroundColor(.cnTextPrimary)
            }
            // ... existing modifiers preserved
    }
}
```

(If `MarkdownTheme.swift` uses different syntax, adapt to whatever the existing file uses — the goal is `iPad-tuned size + serif family`.)

- [ ] **Step 2: Add iPad reader-mode container in SessionDetailView**

Find the main body VStack. Wrap it in a conditional max-width container:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: CNLayout.Spacing.sectionVertical) {
        if CNLayout.isPad {
            iPadHeader
        } else {
            existingHeader
        }
        // ... existing body content
    }
    .padding(.horizontal, CNLayout.Spacing.screenHorizontal)
    .cnPadMaxWidth(CNLayout.MaxWidth.readerBody)
    .padding(.bottom, 32)
}
```

- [ ] **Step 3: Define iPadHeader**

```swift
@ViewBuilder
private var iPadHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("\(formattedDate) · \(session.startsAt)–\(session.endsAt) · \(session.venue)")
            .font(CNFonts.readerMeta)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)

        Text(session.title)
            .font(CNFonts.readerHeadline)
            .foregroundStyle(CNColors.navy(for: colorScheme))
            .lineSpacing(2)

        if let primaryPresenter = session.presentations.first?.presenter, !primaryPresenter.isEmpty {
            Text(primaryPresenter)
                .font(.custom("New York", size: 15).italic())
                .foregroundStyle(CNColors.teal(for: colorScheme))
        }
    }
    .padding(.bottom, 12)
}
```

`formattedDate` should be a small computed property (use existing date formatting if available).

- [ ] **Step 4: Build and run on iPad and iPhone**

⌘B → run on iPad mini sim. Expected: session detail shows large serif headline, uppercase meta line, italic teal presenter name, comfortable margins.

Run on iPhone 15 sim. Expected: identical to current (no visible change).

- [ ] **Step 5: Commit**

```bash
git add ConferenceNav/Views/SessionDetailView.swift ConferenceNav/Design/MarkdownTheme.swift
git commit -m "feat(reader): iPad reader-mode session detail

Larger serif headline, uppercase meta line, italic teal presenter,
generous margins via cnPadMaxWidth. MarkdownTheme switches to
serif body 18pt on iPad. iPhone layout untouched."
```

---

## Phase 6 — PDF Export

### Task 14: report.css

**Files:**
- Create: `ConferenceNav/Resources/report.css`
- Modify: `ConferenceNav/project.yml` (verify Resources dir is in build sources)

- [ ] **Step 1: Write the CSS**

```css
@page {
    size: A4;
    margin: 18mm;
    @bottom-right { content: counter(page); font-family: -apple-system, sans-serif; font-size: 9pt; color: #888; }
}

* { box-sizing: border-box; }
body {
    font-family: "New York", "Times New Roman", Georgia, serif;
    font-size: 11pt;
    line-height: 1.5;
    color: #2A2A35;
    margin: 0;
}

.cover {
    text-align: center;
    page-break-after: always;
    padding-top: 40mm;
}
.cover h1 {
    font-size: 32pt;
    color: #002664;
    margin-bottom: 16pt;
    font-weight: 500;
}
.cover .author { font-size: 14pt; color: #2A2A35; margin-bottom: 8pt; }
.cover .dates { font-size: 12pt; color: #1B6B7D; margin-bottom: 24pt; }
.cover .stats { font-size: 11pt; color: #888; }
.cover .generated {
    color: #C9A227;
    font-size: 9pt;
    font-style: italic;
    margin-top: 32pt;
}

.toc { page-break-after: always; }
.toc h2 { color: #002664; font-size: 22pt; margin-bottom: 16pt; }
.toc ol { list-style: none; padding-left: 0; }
.toc li { margin-bottom: 6pt; font-size: 11pt; }
.toc a { color: #002664; text-decoration: none; }
.toc .day { font-weight: 600; margin-top: 12pt; color: #1B6B7D; }

.session { page-break-before: always; }
.session h2 {
    color: #002664;
    font-size: 18pt;
    margin-bottom: 4pt;
    line-height: 1.18;
}
.session .meta {
    text-transform: uppercase;
    font-size: 9pt;
    letter-spacing: 0.06em;
    color: #888;
    font-family: -apple-system, sans-serif;
    margin-bottom: 8pt;
}
.session .presenter {
    color: #1B6B7D;
    font-style: italic;
    font-size: 11pt;
    margin-bottom: 12pt;
}

img {
    max-width: 100%;
    max-height: 70vh;
    border: 0.5pt solid #ddd;
    border-radius: 4pt;
    margin: 8pt 0 4pt;
    display: block;
}
figure { margin: 12pt 0; }
figcaption {
    font-style: italic;
    color: #888;
    font-size: 9pt;
    text-align: center;
    margin-top: 4pt;
    font-family: -apple-system, sans-serif;
}

h1, h2, h3, h4 { color: #002664; font-weight: 500; }
h3 { font-size: 13pt; margin-top: 14pt; margin-bottom: 4pt; }

p { margin: 0 0 8pt 0; }
ul, ol { margin: 0 0 8pt 1.2em; padding-left: 0.5em; }
li { margin-bottom: 3pt; }

a { color: #1B6B7D; }
em { font-style: italic; }
strong { font-weight: 600; }
code { font-family: "SF Mono", monospace; font-size: 10pt; background: #f4f1eb; padding: 1pt 3pt; }

@media (prefers-color-scheme: dark) {
    /* PDF rendering ignores prefers-color-scheme, so no dark mode needed in PDF output */
}
```

- [ ] **Step 2: Build to verify CSS is bundled**

The `Resources/` directory is already in `project.yml` build sources. Run `cd ConferenceNav && xcodegen generate`. ⌘B.

To verify the CSS is in the bundle, add a quick `print(Bundle.main.url(forResource: "report", withExtension: "css"))` in the app entry, run, observe non-nil URL in console. Remove the print after verification.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Resources/report.css
git commit -m "feat(pdf): add report.css for PDF export styling

Conference palette in print form. Page breaks per session, page numbers
in footer, italic figcaptions, serif body, navy headings. Cover page
+ TOC styles included."
```

---

### Task 15: PDFExportService

**Files:**
- Create: `ConferenceNav/Services/PDFExportService.swift`

- [ ] **Step 1: Build the service**

```swift
import Foundation
import WebKit
import UIKit

@MainActor
final class PDFExportService: NSObject {
    enum Mode {
        case conferenceReport(picks: [Session], notes: [SessionNote], userId: String)
        case allNotes(notes: [SessionNote])
    }

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<URL, Error>?
    private var outputURL: URL?

    func export(mode: Mode, mediaURLProvider: (String) -> URL?) async throws -> URL {
        let html = buildHTML(mode: mode, mediaURLProvider: mediaURLProvider)
        let baseDir = try writeHTMLAndCopyMedia(html: html, mode: mode, mediaURLProvider: mediaURLProvider)
        let htmlURL = baseDir.appendingPathComponent("report.html")
        let outputURL = baseDir.appendingPathComponent(mode.outputFilename)
        self.outputURL = outputURL

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 768, height: 1024), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseDir)
        }
    }

    // MARK: - HTML construction

    private func buildHTML(mode: Mode, mediaURLProvider: (String) -> URL?) -> String {
        let css = (try? String(contentsOf: Bundle.main.url(forResource: "report", withExtension: "css")!, encoding: .utf8)) ?? ""

        var body = ""

        switch mode {
        case .conferenceReport(let picks, let notes, let userId):
            body += renderCover(userId: userId, picks: picks, notes: notes)
            body += renderTOC(picks: picks, notes: notes)
            body += renderConferenceContent(picks: picks, notes: notes)
        case .allNotes(let notes):
            body += renderAllNotes(notes: notes)
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>\(mode.title)</title>
            <style>\(css)</style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private func renderCover(userId: String, picks: [Session], notes: [SessionNote]) -> String {
        let name = fullName(for: userId)
        let totalSketches = notes.reduce(0) { $0 + $1.sketchFilenames.count }
        let formattedToday = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        return """
        <div class="cover">
            <h1>EAPC 2026 — Conference Report</h1>
            <div class="author">\(name)</div>
            <div class="dates">14–16 May 2026 · Prague</div>
            <div class="stats">\(picks.count) picks · \(notes.count) notes · \(totalSketches) sketches</div>
            <div class="generated">Generated \(formattedToday)</div>
        </div>
        """
    }

    private func fullName(for userId: String) -> String {
        switch userId {
        case "ben": return "Benjamin Thomas"
        case "ron": return "Ronald Wai"
        default: return userId.capitalized
        }
    }

    private func renderTOC(picks: [Session], notes: [SessionNote]) -> String {
        let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
        let dayLabels = [
            "2026-05-14": "Thursday, 14 May",
            "2026-05-15": "Friday, 15 May",
            "2026-05-16": "Saturday, 16 May",
        ]
        var html = "<nav class=\"toc\"><h2>Contents</h2><ol>"
        for date in dates {
            let day = picks.filter { $0.date == date }
            if day.isEmpty { continue }
            html += "<li class=\"day\">\(dayLabels[date] ?? date)</li>"
            for s in day {
                html += "<li><a href=\"#session-\(s.id)\">\(escapeHTML(s.title))</a> &nbsp;<span style=\"color:#888\">\(s.startsAt)–\(s.endsAt) · \(s.venue)</span></li>"
            }
        }
        html += "</ol></nav>"
        return html
    }

    private func renderConferenceContent(picks: [Session], notes: [SessionNote]) -> String {
        var html = ""
        for session in picks {
            html += "<article class=\"session\" id=\"session-\(session.id)\">"
            html += "<div class=\"meta\">\(session.date) · \(session.startsAt)–\(session.endsAt) · \(escapeHTML(session.venue))</div>"
            html += "<h2>\(escapeHTML(session.title))</h2>"

            // Note(s) for this session
            let sessionNotes = notes.filter { $0.sessionId == session.id }
            for note in sessionNotes {
                if !note.presentationTitle.isEmpty {
                    html += "<h3>\(escapeHTML(note.presentationTitle))</h3>"
                    if !note.presenter.isEmpty {
                        html += "<div class=\"presenter\">\(escapeHTML(note.presenter))</div>"
                    }
                }
                html += renderMarkdownBody(note.body)
            }
            html += "</article>"
        }
        return html
    }

    private func renderAllNotes(notes: [SessionNote]) -> String {
        var html = "<h1 style=\"color:#002664\">Session Notes — EAPC 2026</h1>"
        for note in notes {
            html += "<article class=\"session\" id=\"note-\(note.noteKey)\">"
            html += "<div class=\"meta\">\(note.sessionDate) · \(note.sessionTime) · \(escapeHTML(note.sessionVenue))</div>"
            html += "<h2>\(escapeHTML(note.displayTitle))</h2>"
            if !note.presenter.isEmpty {
                html += "<div class=\"presenter\">\(escapeHTML(note.presenter))</div>"
            }
            html += renderMarkdownBody(note.body)
            html += "</article>"
        }
        return html
    }

    /// Lightweight Markdown → HTML for the subset we use (headings, lists, images, paragraphs, em/strong).
    /// We avoid pulling in a full MD library — the body content is constrained.
    private func renderMarkdownBody(_ md: String) -> String {
        var html = ""
        let paragraphs = md.components(separatedBy: "\n\n")
        for raw in paragraphs {
            let p = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty { continue }

            if p.hasPrefix("# ")  { html += "<h2>\(escapeInline(String(p.dropFirst(2))))</h2>"; continue }
            if p.hasPrefix("## ") { html += "<h3>\(escapeInline(String(p.dropFirst(3))))</h3>"; continue }
            if p.hasPrefix("### "){ html += "<h4>\(escapeInline(String(p.dropFirst(4))))</h4>"; continue }

            // Image-only paragraph
            if let imgHTML = renderImageParagraph(p) { html += imgHTML; continue }

            // Bullet list
            if p.hasPrefix("- ") || p.hasPrefix("* ") {
                html += "<ul>"
                for line in p.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                        html += "<li>\(escapeInline(String(trimmed.dropFirst(2))))</li>"
                    }
                }
                html += "</ul>"
                continue
            }

            html += "<p>\(escapeInline(p.replacingOccurrences(of: "\n", with: "<br>")))</p>"
        }
        return html
    }

    private func renderImageParagraph(_ p: String) -> String? {
        // Match ![alt](path)
        guard p.hasPrefix("![") else { return nil }
        guard let bracketEnd = p.firstIndex(of: "]"),
              p.index(after: bracketEnd) < p.endIndex,
              p[p.index(after: bracketEnd)] == "(",
              let parenEnd = p.firstIndex(of: ")") else { return nil }
        let path = String(p[p.index(p.index(after: bracketEnd), offsetBy: 1)..<parenEnd])
        return "<figure><img src=\"\(path)\"></figure>"
    }

    private func escapeInline(_ s: String) -> String {
        var x = escapeHTML(s)
        // Bold **text**
        x = x.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        // Italic *text*
        x = x.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
        return x
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - File staging

    private func writeHTMLAndCopyMedia(html: String, mode: Mode, mediaURLProvider: (String) -> URL?) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EAPC-PDF-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Resolve & rewrite media references to local file paths within dir
        var rewritten = html
        let allFilenames = mode.allMediaFilenames
        for filename in allFilenames {
            guard let source = mediaURLProvider(filename) else { continue }
            let dest = dir.appendingPathComponent(filename)
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: source, to: dest)
            // Relative path stays the same — "sketches/abc.png" or "photos/xyz.jpg"
        }

        try rewritten.write(to: dir.appendingPathComponent("report.html"), atomically: true, encoding: .utf8)
        return dir
    }
}

extension PDFExportService.Mode {
    var title: String {
        switch self {
        case .conferenceReport: return "EAPC 2026 Conference Report"
        case .allNotes: return "EAPC 2026 Session Notes"
        }
    }
    var outputFilename: String {
        switch self {
        case .conferenceReport: return "EAPC-2026-Conference-Report.pdf"
        case .allNotes: return "EAPC-2026-Notes.pdf"
        }
    }
    var allMediaFilenames: [String] {
        switch self {
        case .allNotes(let notes), .conferenceReport(_, let notes, _):
            return notes.flatMap { $0.photoFilenames + $0.sketchFilenames.map { "sketches/\($0)" } }
                + notes.flatMap { $0.photoFilenames.map { "photos/\($0)" } }
        }
    }
}

extension PDFExportService: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let outputURL = self.outputURL else { return }
            // Wait briefly for layout / image loading
            try? await Task.sleep(nanoseconds: 600_000_000)
            let config = WKPDFConfiguration()
            // No specific rect → full HTML
            webView.createPDF(configuration: config) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: outputURL)
                            self.continuation?.resume(returning: outputURL)
                        } catch {
                            self.continuation?.resume(throwing: error)
                        }
                    case .failure(let error):
                        self.continuation?.resume(throwing: error)
                    }
                    self.continuation = nil
                    self.webView = nil
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Services/PDFExportService.swift
git commit -m "feat(pdf): add PDFExportService — Markdown → HTML → WKWebView PDF

WKWebView.createPDF pipeline. Generates Conference Report (cover + TOC +
sessions) and All Notes (session-grouped). Lightweight Markdown→HTML
covers the subset used in note bodies. Cover renders Benjamin Thomas /
Ronald Wai based on userId."
```

---

### Task 16: ExportView — add PDF rows

**Files:**
- Modify: `ConferenceNav/Views/ExportView.swift`

- [ ] **Step 1: Add @State for the PDF service + sharePayload extension**

Near the top of `ExportView`:

```swift
@State private var pdfExporter = PDFExportService()
@State private var isExportingPDF = false
```

- [ ] **Step 2: Add PDF rows under the existing Notes & Report section**

After the `All Notes (Markdown)` row, add:

```swift
exportRow(
    title: "Conference Report (PDF)",
    subtitle: "Picks + notes · paginated · TOC",
    icon: "doc.fill",
    iconColor: CNColors.navy(for: colorScheme),
    disabled: store.myPickedSessions.isEmpty && notesStore.notesWithContent.isEmpty
) {
    exportPDF(mode: .conferenceReport(
        picks: store.myPickedSessions,
        notes: notesStore.notesWithContent,
        userId: store.currentUserId
    ))
}

exportRow(
    title: "All Notes (PDF)",
    subtitle: "\(notesStore.notesWithContent.count) notes",
    icon: "doc.text.fill",
    iconColor: CNColors.teal(for: colorScheme),
    disabled: notesStore.notesWithContent.isEmpty
) {
    exportPDF(mode: .allNotes(notes: notesStore.notesWithContent))
}
```

- [ ] **Step 3: Add the exportPDF helper**

```swift
private func exportPDF(mode: PDFExportService.Mode) {
    isExportingPDF = true
    Task {
        defer { isExportingPDF = false }
        do {
            let url = try await pdfExporter.export(mode: mode) { filename in
                notesStore.sketchOrPhotoURL(filename: filename)
                    ?? notesStore.photoURL(filename: filename)
                    ?? notesStore.sketchURL(filename: (filename as NSString).lastPathComponent)
            }
            await MainActor.run {
                sharePayload = SharePayload(items: [url])
            }
        } catch {
            print("PDF export failed: \(error)")
        }
    }
}
```

- [ ] **Step 4: Surface a progress overlay while exporting**

At the end of the body (after `.sheet`):

```swift
.overlay {
    if isExportingPDF {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("Building PDF…").font(.caption).foregroundStyle(.white)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

- [ ] **Step 5: Verify `store.currentUserId` exists**

If it doesn't, add a computed property to `ConferenceStore`:

```swift
var currentUserId: String { /* return the current user's id, e.g. UserDefaults stored "conferenceNavUser" */ }
```

If unsure, read `@AppStorage("conferenceNavUser")` directly in ExportView and pass that.

- [ ] **Step 6: Build and run**

⌘B → run on iPad sim → Extras → Export. Tap **Conference Report (PDF)**. Expect: progress overlay, then share sheet with PDF. Open it in Preview to verify cover page + TOC + per-session pages + page numbers.

- [ ] **Step 7: Commit**

```bash
git add ConferenceNav/Views/ExportView.swift
git commit -m "feat(pdf): surface PDF exports in Export tab

Two new rows: Conference Report (PDF) and All Notes (PDF). Reuses the
existing share-sheet flow. Progress overlay during PDF generation.
Markdown rows untouched."
```

---

## Phase 7 — Tab Polish

### Task 17: Apply iPad max-widths to all four tabs

**Files:**
- Modify: `ConferenceNav/Views/ScheduleView.swift`
- Modify: `ConferenceNav/Views/SearchView.swift`
- Modify: `ConferenceNav/Views/MyPicksView.swift`
- Modify: `ConferenceNav/Views/ExtrasView.swift`

For each of the four files, find the top-level `List` or `ScrollView` and apply `.cnPadMaxWidth(CNLayout.MaxWidth.tabContent)`.

- [ ] **Step 1: Schedule view**

Open `ScheduleView.swift`. Find the body's main container (likely `List` or `ScrollView`). Append:

```swift
.cnPadMaxWidth(CNLayout.MaxWidth.tabContent)
```

If the existing structure has a `NavigationStack { List { ... } }`, the modifier goes on the `List`.

- [ ] **Step 2: Search view**

Same pattern.

- [ ] **Step 3: My Picks view**

Same pattern.

- [ ] **Step 4: Extras view**

Same pattern.

- [ ] **Step 5: Build on iPad mini sim and inspect each tab**

Each should now have a centred 720pt-wide content column on iPad. iPhone unchanged.

- [ ] **Step 6: Commit**

```bash
git add ConferenceNav/Views/ScheduleView.swift ConferenceNav/Views/SearchView.swift ConferenceNav/Views/MyPicksView.swift ConferenceNav/Views/ExtrasView.swift
git commit -m "feat(ipad): apply max-width container to all four tabs

Schedule / Search / My Picks / Extras get centred 720pt content column
on iPad via cnPadMaxWidth. iPhone full-bleed layout unchanged."
```

---

## Phase 8 — Verification

### Task 18: iPhone regression sweep

- [ ] **Step 1: Boot iPhone 15 simulator**

```bash
xcrun simctl boot "iPhone 15" 2>/dev/null; open -a Simulator
```

Build & run on iPhone 15.

- [ ] **Step 2: Walk every iPhone flow**

Verify nothing visibly changed:
- Splash → user picker (or auto-skip if user is set)
- Schedule tab: pick a session, deep-dive into detail
- Search tab: search "SILENCE", filter by Keynote
- My Picks tab: toggle Mine/Ben/Ron/Both
- Extras tab: add a contact, edit a note, export a Markdown report
- Verify Sketch button is **disabled** in note editor on iPhone
- Verify session detail uses the *original* compact iPhone layout, not reader mode
- Verify all four tab views still scroll edge-to-edge with no centred-column constraint

If any flow looks different from before V6/V7 work began: file a regression and fix before continuing.

- [ ] **Step 3: Verify PDF export on iPhone**

Extras → Export → Conference Report (PDF). Confirm the share sheet returns a valid PDF that opens in Preview. (PDF export is shared between iPhone and iPad — Ron uses it from iPhone.)

- [ ] **Step 4: Commit any regression fixes (if any)**

```bash
git add <fixed-files>
git commit -m "fix: address iPhone regression in <area>"
```

---

### Task 19: Ben's iPad walkthrough (manual)

**This is Ben's task to run on his physical iPad mini before TestFlight push.**

- [ ] **Step 1: Build + install via Xcode**

Connect iPad mini to Mac. Select iPad mini as Run destination. ⌘R.

- [ ] **Step 2: Sketch flow end-to-end**

- Open any session → Notes → tap **+ Sketch**
- Draw a few words and a diagram with Pencil
- Verify finger doesn't draw (only pans/scrolls)
- Switch tools: pen → marker → eraser → back to pen
- Pick a colour from the palette
- Tap Save → verify "Transcribing…" overlay
- Verify image + transcription appear inline in the note body

- [ ] **Step 3: Reopen sketch flow**

- Tap an existing sketch thumbnail in the MediaStrip
- Add more strokes
- Save → verify the Replace/Append/Skip OCR prompt appears
- Pick "Replace" → verify transcription is replaced

- [ ] **Step 4: Reader-mode session detail**

- Open a session detail → verify large serif headline, uppercase meta, italic teal presenter

- [ ] **Step 5: PDF export**

- Extras → Export → Conference Report (PDF) → save to Files
- Open in Apple Books or Files → verify cover, TOC links jump correctly, page numbers, sketches inline

- [ ] **Step 6: iCloud sync check**

- On iPhone: open the note that has a sketch from iPad
- Verify sketch image renders (PNG sync via iCloud)
- (If sync hasn't propagated yet, wait a minute and re-open)

- [ ] **Step 7: Push to TestFlight**

```bash
# In Xcode: Product → Archive → Distribute App → TestFlight
```

Tag the release:

```bash
git tag v1.2-pencil-pdf-ipad
git push origin v1.2-pencil-pdf-ipad
```

---

## Self-Review

- [x] **Spec coverage:** Every numbered goal in V6 and V7 specs maps to a task. V6: PencilKit (Tasks 3–7), OCR (Task 8–9), inline flow (Task 11), PDF export (Tasks 14–16), MD kept (Tasks 14–16 leave existing). V7: idiom helper (Task 1), reader mode (Tasks 12–13), sketch editor on iPad (Tasks 3–7), note editor iPad (Tasks 10–11), tab polish (Task 17), iPhone unchanged (Task 18 regression sweep).
- [x] **Placeholder scan:** No "TBD" / "fill in" / "similar to Task N". Every code-changing step has the actual code.
- [x] **Type consistency:** `OCRDecision` (Task 9) used in Task 11. `SketchToolKind` (Task 5) used in Task 6. `MediaStrip.MediaItem` (Task 10) used in Task 11. `PDFExportService.Mode` (Task 15) used in Task 16. `CNLayout.MaxWidth.*` (Task 1) used in Tasks 13/17.
- [x] **Sequencing:** Foundation tasks (1–2) come before consumers. Sketch editor (3–7) before NoteEditorView wires it (Task 11). OCR (8–9) before NoteEditorView calls it (Task 11). Reader-mode component (12) before SessionDetailView uses it (Task 13). PDF service (15) before ExportView surfaces it (Task 16). Tab polish (17) is independent. Regression sweep (18) and Ben's walkthrough (19) come last.

---

## Open notes

- **Venue map pin fix** is *not* in this plan — Ben deferred it pending a screenshot. After Ben sends the screenshot, fold that work into a separate small commit.
- **iCloud Drive sync** is already free via existing ubiquity container; nothing to add.
- **APNs push** for sketch-related events: out of scope for V6/V7.
- **Ron's experience:** entirely unchanged except gaining PDF export. Verified explicitly in Task 18.
