import SwiftUI

struct NoteListView: View {
    @Environment(NotesStore.self) var notesStore
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var editingSessionId: Int?

    private var isShowingEditor: Binding<Bool> {
        Binding(
            get: { editingSessionId != nil },
            set: { if !$0 { editingSessionId = nil } }
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
            if let sessionId = editingSessionId,
               let session = store.sessions.first(where: { $0.id == sessionId }) {
                NoteEditorView(session: session)
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
            Text("Open a session and tap the notes icon\nto start capturing your thoughts.")
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
                    editingSessionId = note.sessionId
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.sessionTitle)
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            .lineLimit(2)

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

                        // Note preview
                        Text(note.body.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(CNFonts.body)
                            .foregroundStyle(CNColors.textSecondary)
                            .lineLimit(2)

                        if !note.photoFilenames.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                Text("\(note.photoFilenames.count) photo\(note.photoFilenames.count == 1 ? "" : "s")")
                                    .font(CNFonts.small)
                            }
                            .foregroundStyle(CNColors.gold(for: colorScheme))
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
