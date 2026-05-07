import SwiftUI

struct NoteListView: View {
    @Environment(NotesStore.self) var notesStore
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var editingNote: SessionNote?

    private var isShowingEditor: Binding<Bool> {
        Binding(
            get: { editingNote != nil },
            set: { if !$0 { editingNote = nil } }
        )
    }

    var body: some View {
        Group {
            if notesStore.notesWithContent.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CNColors.background(for: colorScheme))
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Session Notes")
        .sheet(isPresented: isShowingEditor) {
            if let note = editingNote,
               let session = store.sessions.first(where: { $0.id == note.sessionId }) {
                Group {
                    if let presId = note.presentationId,
                       let pres = session.presentations.first(where: { $0.id == presId }) {
                        NoteEditorView(session: session, presentation: pres)
                    } else {
                        NoteEditorView(session: session, presentation: nil)
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(CNColors.teal(for: colorScheme).opacity(0.4))
            Text("No notes yet")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            Text("Open a session and tap the notes icon\non any talk or poster to start.")
                .font(CNFonts.body)
                .foregroundStyle(CNColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var notesList: some View {
        List {
            ForEach(notesStore.notesWithContent) { note in
                Button {
                    editingNote = note
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        // Primary title: presentation or session
                        Text(note.displayTitle)
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            .lineLimit(2)

                        // Presenter (for presentation-level notes)
                        if !note.presenter.isEmpty {
                            Text(note.presenter)
                                .font(CNFonts.caption)
                                .foregroundStyle(CNColors.teal(for: colorScheme))
                        }

                        // Parent session (for presentation-level notes)
                        if note.presentationId != nil {
                            Text(note.sessionTitle)
                                .font(CNFonts.small)
                                .foregroundStyle(CNColors.textSecondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Text(note.sessionDate)
                                .font(CNFonts.timeSmall)
                            Text("·")
                            Text(note.sessionTime)
                                .font(CNFonts.timeSmall)
                            Text("·")
                            Text(note.sessionVenue)
                                .font(CNFonts.caption)
                        }
                        .foregroundStyle(CNColors.teal(for: colorScheme))

                        // Note preview — strip image markdown so the line shows
                        // prose (or transcribed text) instead of `![sketch](...)`.
                        let preview = note.bodyWithoutImages
                        if !preview.isEmpty {
                            Text(preview)
                                .font(CNFonts.body)
                                .foregroundStyle(CNColors.textSecondary)
                                .lineLimit(2)
                        }

                        // Photo + sketch badges. Sketch count parses the body so
                        // legacy notes (where sketchFilenames may be empty)
                        // still surface the correct number.
                        let sketchCount = max(note.sketchFilenames.count, note.inlineSketchCount)
                        if !note.photoFilenames.isEmpty || sketchCount > 0 {
                            HStack(spacing: 10) {
                                if !note.photoFilenames.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 11))
                                        Text("\(note.photoFilenames.count) photo\(note.photoFilenames.count == 1 ? "" : "s")")
                                            .font(CNFonts.small)
                                    }
                                    .foregroundStyle(CNColors.gold(for: colorScheme))
                                }
                                if sketchCount > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "scribble.variable")
                                            .font(.system(size: 11))
                                        Text("\(sketchCount) sketch\(sketchCount == 1 ? "" : "es")")
                                            .font(CNFonts.small)
                                    }
                                    .foregroundStyle(CNColors.teal(for: colorScheme))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .onDelete { offsets in
                let sorted = notesStore.notesWithContent
                for index in offsets {
                    notesStore.delete(sorted[index])
                }
            }
        }
        .listStyle(.plain)
    }
}
