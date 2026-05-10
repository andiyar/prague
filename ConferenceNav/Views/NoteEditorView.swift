import SwiftUI
import MarkdownUI
import PhotosUI
import PencilKit

struct NoteEditorView: View {
    let session: Session
    let presentation: Presentation?

    @Environment(NotesStore.self) var notesStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var noteBody: String = ""
    @State private var photoFilenames: [String] = []
    @State private var sketchFilenames: [String] = []
    @State private var isPreview = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPhotoSource = false
    @State private var hasLoaded = false
    @State private var showSketchEditor = false
    @State private var pendingSketchEdit: (filename: String, drawing: PKDrawing)?
    @State private var isSketchSaving = false

    init(session: Session, presentation: Presentation? = nil) {
        self.session = session
        self.presentation = presentation
    }

    private var currentNote: SessionNote {
        if let pres = presentation {
            return notesStore.note(for: pres, in: session)
        }
        return notesStore.note(for: session)
    }

    private var noteTitle: String {
        presentation?.title ?? session.title
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contextHeader
                Divider()

                if isPreview {
                    previewMode
                } else {
                    editMode
                        .cnPadMaxWidth(CNLayout.MaxWidth.noteEditor)
                }

                if !photoFilenames.isEmpty && !CNLayout.isPad {
                    photoStrip
                }

                if CNLayout.isPad {
                    MediaStrip(
                        photoFilenames: photoFilenames,
                        sketchFilenames: sketchFilenames,
                        onAddSketch: {
                            pendingSketchEdit = nil
                            showSketchEditor = true
                        },
                        onAddPhoto: {
                            showingPhotoSource = true
                        },
                        onTapMedia: { item in
                            switch item {
                            case .photo:
                                break
                            case .sketch(let f):
                                if let d = notesStore.loadSketchDrawing(filename: f) {
                                    pendingSketchEdit = (filename: f, drawing: d)
                                    showSketchEditor = true
                                }
                            }
                        },
                        onDeleteMedia: { item in
                            switch item {
                            case .photo(let f):
                                removePhoto(f)
                            case .sketch(let f):
                                removeSketch(f)
                            }
                        }
                    )
                    .cnPadMaxWidth(CNLayout.MaxWidth.noteEditor)
                }
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSketchSaving)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation { isPreview.toggle() }
                    } label: {
                        Image(systemName: isPreview ? "pencil" : "eye")
                            .foregroundStyle(CNColors.navy(for: colorScheme))
                    }

                    Button {
                        showingPhotoSource = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(CNColors.navy(for: colorScheme))
                    }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingPhotoSource) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showingCamera = true }
                }
                Button("Choose from Library") { showingPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView { image in
                    attachPhoto(image)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    attachPhoto(image)
                }
            }
            .fullScreenCover(isPresented: $showSketchEditor) {
                SketchEditorView(
                    sessionTitle: currentNote.displayTitle,
                    initialDrawing: pendingSketchEdit?.drawing ?? PKDrawing(),
                    onCancel: {
                        showSketchEditor = false
                        pendingSketchEdit = nil
                    },
                    onSave: { drawing, image, decision in
                        showSketchEditor = false
                        isSketchSaving = true
                        Task { await handleSketchSave(drawing: drawing, image: image, decision: decision) }
                    }
                )
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                let note = currentNote
                noteBody = note.body
                photoFilenames = note.photoFilenames
                sketchFilenames = note.sketchFilenames
            }
        }
    }

    // MARK: - Context Header

    private var contextHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pres = presentation {
                // Presentation-level note
                Text(pres.title)
                    .font(CNFonts.headline)
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    .lineLimit(2)

                if !pres.presenter.isEmpty {
                    Text(pres.presenter)
                        .font(CNFonts.caption)
                        .foregroundStyle(CNColors.teal(for: colorScheme))
                }

                Text(session.title)
                    .font(CNFonts.small)
                    .foregroundStyle(CNColors.textSecondary)
                    .lineLimit(1)
            } else {
                // Session-level note
                Text(session.title)
                    .font(CNFonts.headline)
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                Text(session.dayLabel)
                    .font(CNFonts.caption)
                Text("·")
                Text("\(session.startsAt)-\(session.endsAt)")
                    .font(CNFonts.timeSmall)
                Text("·")
                Text(session.venue)
                    .font(CNFonts.caption)
            }
            .foregroundStyle(CNColors.teal(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(CNColors.surface(for: colorScheme))
    }

    // MARK: - Edit Mode

    private var editMode: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                markdownHint("**bold**")
                markdownHint("*italic*")
                markdownHint("## heading")
                markdownHint("- list")
                markdownHint("> quote")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(CNColors.surfaceSecondary(for: colorScheme))

            TextEditor(text: $noteBody)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
    }

    private func markdownHint(_ text: String) -> some View {
        Text(text)
            .font(CNFonts.mono(11))
            .foregroundStyle(CNColors.textSecondary)
    }

    // MARK: - Preview Mode

    private var previewMode: some View {
        ScrollView {
            if noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 60)
                    Text("No notes yet")
                        .font(CNFonts.title2)
                        .foregroundStyle(CNColors.textSecondary)
                    Text("Tap the pencil icon to start writing.")
                        .font(CNFonts.body)
                        .foregroundStyle(CNColors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Markdown(noteBody)
                    .markdownTheme(.conference(colorScheme: colorScheme))
                    .markdownImageProvider(LocalMediaImageProvider(notesStore: notesStore))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Photos (\(photoFilenames.count))")
                .font(CNFonts.caption)
                .foregroundStyle(CNColors.textSecondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photoFilenames, id: \.self) { filename in
                        if let image = notesStore.loadPhoto(filename: filename) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        removePhoto(filename)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
        .background(CNColors.surface(for: colorScheme))
    }

    // MARK: - Actions

    private func attachPhoto(_ image: UIImage) {
        guard let filename = notesStore.savePhoto(image, for: currentNote) else { return }
        photoFilenames.append(filename)
        // Insert the image reference inline at the end of the body — matches
        // the sketch flow so photos render in context (in preview, in
        // markdown export, in the PDF) instead of being clustered at the
        // bottom. The user can manually move the ref earlier in the body
        // via the markdown editor if they want a different position.
        let imgRef = "![photo](photos/\(filename))"
        if noteBody.isEmpty {
            noteBody = imgRef + "\n"
        } else {
            noteBody += "\n\n" + imgRef + "\n"
        }
    }

    private func removePhoto(_ filename: String) {
        photoFilenames.removeAll { $0 == filename }
        notesStore.deletePhoto(filename: filename)
        // Strip the inline image reference from the body too. Mirrors
        // removeSketch — leave any user-typed prose adjacent to the photo
        // alone, just nuke the image ref + leading paragraph break.
        let imgRef = "![photo](photos/\(filename))"
        if let range = noteBody.range(of: "\n\n" + imgRef) {
            noteBody.removeSubrange(range)
        } else if let range = noteBody.range(of: imgRef) {
            noteBody.removeSubrange(range)
        }
    }

    private func removeSketch(_ filename: String) {
        sketchFilenames.removeAll { $0 == filename }
        notesStore.deleteSketch(filename: filename)
        // Strip the inline image reference (and the leading paragraph break) from the body.
        // Leave any trailing transcription paragraph alone — it's edited prose at this point.
        let imgRef = "![sketch](sketches/\(filename))"
        if let range = noteBody.range(of: "\n\n" + imgRef) {
            noteBody.removeSubrange(range)
        } else if let range = noteBody.range(of: imgRef) {
            noteBody.removeSubrange(range)
        }
    }

    // MARK: - Sketch handling

    private func handleSketchSave(drawing: PKDrawing, image: UIImage, decision: OCRDecision) async {
        defer { isSketchSaving = false }
        guard let pngFilename = notesStore.saveSketch(drawing: drawing, image: image) else { return }

        if let existing = pendingSketchEdit {
            notesStore.deleteSketch(filename: existing.filename)
            noteBody = noteBody.replacingOccurrences(of: "sketches/\(existing.filename)", with: "sketches/\(pngFilename)")
            if let idx = sketchFilenames.firstIndex(of: existing.filename) {
                sketchFilenames[idx] = pngFilename
            }
        } else {
            sketchFilenames.append(pngFilename)
        }

        let transcription: String? = await {
            switch decision {
            case .skip: return nil
            case .firstSave, .replace, .append: return await SketchOCR.transcribe(image: image)
            }
        }()

        if pendingSketchEdit == nil {
            let block = "\n\n![sketch](sketches/\(pngFilename))\n\n\(transcription ?? "")\n"
            noteBody += block
        } else if let t = transcription {
            switch decision {
            case .replace:
                noteBody = replaceTranscriptionAfterImage(filename: pngFilename, body: noteBody, with: t)
            case .append:
                noteBody = appendTranscriptionAfterImage(filename: pngFilename, body: noteBody, with: t)
            case .skip, .firstSave:
                break
            }
        }

        var note = currentNote
        note.body = noteBody
        note.photoFilenames = photoFilenames
        note.sketchFilenames = sketchFilenames
        notesStore.save(note)
        pendingSketchEdit = nil
    }

    private func replaceTranscriptionAfterImage(filename: String, body: String, with text: String) -> String {
        let imgRef = "![sketch](sketches/\(filename))"
        guard let range = body.range(of: imgRef) else { return body }
        let afterImage = body[range.upperBound...]

        // Find the paragraph immediately following the image
        guard let firstParagraphStart = afterImage.range(of: "\n\n") else {
            // No paragraph after image at all — append a fresh transcription
            return body + "\n\n" + text
        }

        let paragraphContentStart = firstParagraphStart.upperBound
        let nextParagraphBreak = afterImage[paragraphContentStart...].range(of: "\n\n")
        let paragraphEnd = nextParagraphBreak?.lowerBound ?? afterImage.endIndex
        let paragraphSubstring = afterImage[paragraphContentStart..<paragraphEnd]
        let paragraphTrimmed = paragraphSubstring.trimmingCharacters(in: .whitespaces)

        // If the next paragraph is structural (another image, a heading, or a list), don't replace it.
        // Insert a new transcription paragraph BEFORE the structural element instead.
        let isStructural = paragraphTrimmed.hasPrefix("![")
            || paragraphTrimmed.hasPrefix("#")
            || paragraphTrimmed.hasPrefix("- ")
            || paragraphTrimmed.hasPrefix("* ")

        let prefix = body[..<range.upperBound]
        if isStructural {
            let suffix = afterImage  // include the structural paragraph and everything after
            return "\(prefix)\n\n\(text)\(suffix)"
        } else {
            let suffix = afterImage[paragraphEnd...]
            return "\(prefix)\n\n\(text)\(suffix)"
        }
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
            return "\(prefix)\(middle)\n\n\(text)\(suffix)"
        }
        return body + "\n\n" + text
    }

    private func saveAndDismiss() {
        var note = currentNote
        note.body = noteBody
        note.photoFilenames = photoFilenames
        note.sketchFilenames = sketchFilenames

        let hasContent = !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !photoFilenames.isEmpty
            || !sketchFilenames.isEmpty
        let noteKey = note.noteKey
        let hadNote = notesStore.notes.contains { $0.noteKey == noteKey }

        if hasContent {
            notesStore.save(note)
        } else if hadNote {
            notesStore.delete(note)
        }
        dismiss()
    }
}
