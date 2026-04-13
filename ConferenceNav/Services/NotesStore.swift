import SwiftUI
import UIKit

@Observable
class NotesStore {
    private(set) var notes: [SessionNote] = []
    private(set) var isLoading = false

    private let userId: String
    private let fileQueue = DispatchQueue(label: "com.wheresBen.ConferenceNav.notes", qos: .userInitiated)

    init(userId: String) {
        self.userId = userId
        loadNotes()
    }

    // MARK: - Public API

    /// Get or create a note for a presentation within a session
    func note(for presentation: Presentation, in session: Session) -> SessionNote {
        let key = "p-\(presentation.id)"
        if let existing = notes.first(where: { $0.noteKey == key }) {
            return existing
        }
        return SessionNote(
            sessionId: session.id,
            sessionTitle: session.title,
            sessionDate: session.date,
            sessionTime: "\(session.startsAt)-\(session.endsAt)",
            sessionVenue: session.venue,
            presentationId: presentation.id,
            presentationTitle: presentation.title,
            presenter: presentation.presenter
        )
    }

    /// Get or create a session-level note (for sessions with no presentations)
    func note(for session: Session) -> SessionNote {
        let key = "s-\(session.id)"
        if let existing = notes.first(where: { $0.noteKey == key }) {
            return existing
        }
        return SessionNote(
            sessionId: session.id,
            sessionTitle: session.title,
            sessionDate: session.date,
            sessionTime: "\(session.startsAt)-\(session.endsAt)",
            sessionVenue: session.venue
        )
    }

    /// Check if a presentation has a note with content
    func hasNote(forPresentation presentationId: Int) -> Bool {
        let key = "p-\(presentationId)"
        guard let note = notes.first(where: { $0.noteKey == key }) else { return false }
        return !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.photoFilenames.isEmpty
    }

    /// Check if a session has a note with content (session-level only)
    func hasNote(forSession sessionId: Int) -> Bool {
        let key = "s-\(sessionId)"
        guard let note = notes.first(where: { $0.noteKey == key }) else { return false }
        return !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.photoFilenames.isEmpty
    }

    /// Check if any notes exist for a session (session-level or any of its presentations)
    func hasAnyNote(forSession sessionId: Int) -> Bool {
        notes.contains { note in
            note.sessionId == sessionId &&
            (!note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.photoFilenames.isEmpty)
        }
    }

    /// Save a note (creates or updates)
    func save(_ note: SessionNote) {
        var updated = note
        updated.lastModified = Date()

        if let index = notes.firstIndex(where: { $0.noteKey == note.noteKey }) {
            notes[index] = updated
        } else {
            notes.append(updated)
        }
        persistNote(updated)
    }

    /// Delete a note and its photos
    func delete(_ note: SessionNote) {
        notes.removeAll { $0.noteKey == note.noteKey }
        deleteNoteFile(note)
    }

    /// Save a photo, returns the filename
    func savePhoto(_ image: UIImage, for note: SessionNote) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let prefix = note.presentationId.map { "pres-\($0)" } ?? "session-\(note.sessionId)"
        let filename = "\(prefix)-\(UUID().uuidString.prefix(8)).jpg"
        let photosDir = photosDirectory()

        do {
            try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
            let fileURL = photosDir.appendingPathComponent(filename)
            try data.write(to: fileURL)
            return filename
        } catch {
            print("NotesStore: Failed to save photo: \(error)")
            return nil
        }
    }

    /// Load a photo by filename
    func loadPhoto(filename: String) -> UIImage? {
        let url = photosDirectory().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Delete a photo file
    func deletePhoto(filename: String) {
        let url = photosDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// All notes sorted by session date/time, then presentation
    var sortedNotes: [SessionNote] {
        notes.sorted { a, b in
            if a.sessionDate != b.sessionDate { return a.sessionDate < b.sessionDate }
            if a.sessionTime != b.sessionTime { return a.sessionTime < b.sessionTime }
            return a.displayTitle < b.displayTitle
        }
    }

    /// Notes that have content (for export/listing)
    var notesWithContent: [SessionNote] {
        sortedNotes.filter {
            !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.photoFilenames.isEmpty
        }
    }

    // MARK: - Export

    /// Generate a combined conference report from all notes
    func exportConferenceReport(pickedSessions: [Session]) -> String {
        let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
        let dayLabels = [
            "2026-05-14": "Wednesday, 14 May",
            "2026-05-15": "Thursday, 15 May",
            "2026-05-16": "Friday, 16 May",
        ]

        var md = "# EAPC 2026 Conference Report\n\n"
        md += "*Generated \(formattedDate(Date()))*\n\n"
        md += "---\n\n"

        for date in dates {
            let daySessions = pickedSessions.filter { $0.date == date }
            if daySessions.isEmpty { continue }

            md += "## \(dayLabels[date] ?? date)\n\n"

            for session in daySessions {
                md += "### \(session.startsAt)-\(session.endsAt) · \(session.venue)\n"
                md += "**\(session.title)** (\(session.type.rawValue))\n\n"

                // Session-level note
                let sessionNote = notes.first(where: { $0.noteKey == "s-\(session.id)" })
                if let note = sessionNote,
                   !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    md += note.body + "\n\n"
                }

                // Presentation-level notes
                let presNotes = notes.filter { $0.sessionId == session.id && $0.presentationId != nil }
                    .filter { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.photoFilenames.isEmpty }

                if !presNotes.isEmpty {
                    for pNote in presNotes {
                        md += "#### \(pNote.presentationTitle)\n"
                        if !pNote.presenter.isEmpty {
                            md += "*\(pNote.presenter)*\n\n"
                        }
                        md += pNote.body + "\n\n"
                        if !pNote.photoFilenames.isEmpty {
                            md += "*Photos: \(pNote.photoFilenames.joined(separator: ", "))*\n\n"
                        }
                    }
                } else if sessionNote == nil {
                    md += "*No notes recorded.*\n\n"
                }
            }
        }

        return md
    }

    // MARK: - File I/O

    private func notesDirectory() -> URL {
        let base = containerURL()
        return base.appendingPathComponent("notes")
    }

    private func photosDirectory() -> URL {
        let base = containerURL()
        return base.appendingPathComponent("photos")
    }

    /// Returns iCloud Drive Documents URL if available, otherwise local Documents
    private func containerURL() -> URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            return iCloudURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func loadNotes() {
        isLoading = true
        fileQueue.async { [weak self] in
            guard let self else { return }
            let dir = self.notesDirectory()

            guard FileManager.default.fileExists(atPath: dir.path) else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            do {
                let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "md" }

                var loaded: [SessionNote] = []
                for file in files {
                    let content = try String(contentsOf: file, encoding: .utf8)
                    if let note = SessionNote.fromMarkdown(content) {
                        loaded.append(note)
                    }
                }

                DispatchQueue.main.async {
                    self.notes = loaded
                    self.isLoading = false
                }
            } catch {
                print("NotesStore: Failed to load notes: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }

    private func persistNote(_ note: SessionNote) {
        fileQueue.async { [weak self] in
            guard let self else { return }
            let dir = self.notesDirectory()

            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let fileURL = dir.appendingPathComponent(note.filename)
                try note.toMarkdown().write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("NotesStore: Failed to save note: \(error)")
            }
        }
    }

    private func deleteNoteFile(_ note: SessionNote) {
        fileQueue.async { [weak self] in
            guard let self else { return }
            let fileURL = self.notesDirectory().appendingPathComponent(note.filename)
            try? FileManager.default.removeItem(at: fileURL)

            for photo in note.photoFilenames {
                let photoURL = self.photosDirectory().appendingPathComponent(photo)
                try? FileManager.default.removeItem(at: photoURL)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: date)
    }
}
