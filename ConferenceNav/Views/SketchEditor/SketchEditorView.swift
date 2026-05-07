import SwiftUI
import PencilKit

enum OCRDecision {
    case none           // first-time save → caller decides what to do (typically: run OCR)
    case replace        // re-save: replace existing transcription
    case append         // re-save: append new transcription
    case skip           // re-save: keep existing transcription, don't OCR again
}

struct SketchEditorView: View {
    let sessionTitle: String
    let initialDrawing: PKDrawing
    let onCancel: () -> Void
    let onSave: (PKDrawing, UIImage, OCRDecision) -> Void

    @State private var drawing: PKDrawing
    @State private var tool: PKTool = PKInkingTool(.pen, color: UIColor(red: 0, green: 0.15, blue: 0.39, alpha: 1), width: 2)
    @State private var selectedToolKind: SketchToolKind = .pen
    @State private var selectedColor: Color = Color(red: 0, green: 0.15, blue: 0.39)
    @State private var selectedWidth: SketchWidth = .medium
    @State private var canvasView = PKCanvasView()
    @State private var showOCRPrompt = false
    @State private var isSaving = false
    private var isReedit: Bool { !initialDrawing.strokes.isEmpty }

    init(
        sessionTitle: String,
        initialDrawing: PKDrawing = PKDrawing(),
        onCancel: @escaping () -> Void,
        onSave: @escaping (PKDrawing, UIImage, OCRDecision) -> Void
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
                selectedWidth: $selectedWidth,
                onUndo: { canvasView.undoManager?.undo() },
                onRedo: { canvasView.undoManager?.redo() }
            )
            ZStack {
                DotGridBackground()
                CanvasContainer(canvas: canvasView, drawing: $drawing, tool: $tool)
            }
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedToolKind) { _, _ in updateTool() }
        .onChange(of: selectedColor) { _, _ in updateTool() }
        .onChange(of: selectedWidth) { _, _ in updateTool() }
        .onAppear { updateTool() }
        .confirmationDialog(
            "Sketch updated — what about the transcription?",
            isPresented: $showOCRPrompt,
            titleVisibility: .visible
        ) {
            Button("Replace existing transcription") { isSaving = true; save(decision: .replace) }
            Button("Append new transcription") { isSaving = true; save(decision: .append) }
            Button("Skip OCR (keep transcription as-is)") { isSaving = true; save(decision: .skip) }
            Button("Cancel", role: .cancel) {}
        }
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
                if isReedit {
                    showOCRPrompt = true
                } else {
                    isSaving = true
                    save(decision: .none)
                }
            } label: {
                Text("Save").fontWeight(.semibold).foregroundStyle(.white)
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0, green: 0.15, blue: 0.39))
    }

    private func save(decision: OCRDecision) {
        // Prefer the bounding box of the actual strokes — keeps the saved PNG
        // tight to what was drawn, so it embeds in notes/exports without acres
        // of empty whitespace. Fall back to the full canvas only when nothing
        // has been drawn yet.
        let renderRect: CGRect
        let strokeBounds = canvasView.drawing.bounds
        if !strokeBounds.isEmpty {
            // Pad 24pt on each side so strokes aren't crammed against the edge.
            renderRect = strokeBounds.insetBy(dx: -24, dy: -24)
        } else if !canvasView.bounds.isEmpty {
            renderRect = canvasView.bounds
        } else {
            renderRect = CGRect(x: 0, y: 0, width: 768, height: 1024)
        }
        let scale = canvasView.traitCollection.displayScale > 0
            ? canvasView.traitCollection.displayScale
            : 2.0
        let image = canvasView.drawing.image(from: renderRect, scale: scale)
        onSave(canvasView.drawing, image, decision)
    }

    private func updateTool() {
        let uiColor = UIColor(selectedColor)
        let w = selectedWidth.width(for: selectedToolKind)
        switch selectedToolKind {
        case .pen:    tool = PKInkingTool(.pen, color: uiColor, width: w)
        case .pencil: tool = PKInkingTool(.pencil, color: uiColor, width: w)
        case .marker: tool = PKInkingTool(.marker, color: uiColor, width: w)
        case .eraser: tool = PKEraserTool(.vector)
        }
    }
}

private struct CanvasContainer: UIViewRepresentable {
    let canvas: PKCanvasView
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
        onSave: { _, _, _ in }
    )
}
