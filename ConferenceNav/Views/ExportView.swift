import SwiftUI

struct ExportView: View {
    @Environment(ContactStore.self) var contactStore
    @Environment(ConferenceStore.self) var store
    @Environment(NotesStore.self) var notesStore
    @Environment(\.colorScheme) var colorScheme

    @State private var sharePayload: SharePayload?
    @State private var pdfExporter = PDFExportService()
    @State private var isExportingPDF = false
    @AppStorage("conferenceNavUser") private var userId: String = "ben"

    var body: some View {
        List {
            Section {
                exportRow(
                    title: "People (Markdown)",
                    subtitle: "\(contactStore.contacts.count) contacts",
                    icon: "person.crop.rectangle.stack",
                    iconColor: CNColors.teal(for: colorScheme),
                    disabled: contactStore.contacts.isEmpty
                ) {
                    exportFile(
                        content: contactStore.exportAsMarkdown(),
                        filename: "EAPC-2026-Contacts.md"
                    )
                }

                exportRow(
                    title: "People (CSV)",
                    subtitle: "Spreadsheet-ready",
                    icon: "tablecells",
                    iconColor: CNColors.teal(for: colorScheme),
                    disabled: contactStore.contacts.isEmpty
                ) {
                    exportFile(
                        content: contactStore.exportAsCSV(),
                        filename: "EAPC-2026-Contacts.csv"
                    )
                }
            } header: {
                Text("Contacts")
            }

            Section {
                exportRow(
                    title: "My Picks (Markdown)",
                    subtitle: "\(store.myPickedSessions.count) sessions",
                    icon: "star.fill",
                    iconColor: CNColors.gold(for: colorScheme),
                    disabled: store.myPickedSessions.isEmpty
                ) {
                    exportFile(
                        content: exportPicksMarkdown(),
                        filename: "EAPC-2026-MyPicks.md"
                    )
                }
            } header: {
                Text("Programme")
            }

            Section {
                exportRow(
                    title: "Conference Report",
                    subtitle: "Picks + notes combined",
                    icon: "doc.richtext",
                    iconColor: CNColors.navy(for: colorScheme),
                    disabled: store.myPickedSessions.isEmpty && notesStore.notesWithContent.isEmpty
                ) {
                    exportWithPhotos(
                        content: notesStore.exportConferenceReport(
                            pickedSessions: store.myPickedSessions,
                            allSessions: store.sessions
                        ),
                        filename: "EAPC-2026-Conference-Report.md",
                        photoFilenames: notesStore.allPhotoFilenames
                    )
                }

                exportRow(
                    title: "All Notes (Markdown)",
                    subtitle: "\(notesStore.notesWithContent.count) notes",
                    icon: "note.text",
                    iconColor: CNColors.teal(for: colorScheme),
                    disabled: notesStore.notesWithContent.isEmpty
                ) {
                    exportWithPhotos(
                        content: exportAllNotes(),
                        filename: "EAPC-2026-Notes.md",
                        photoFilenames: notesStore.allPhotoFilenames
                    )
                }

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
                        userId: userId
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
            } header: {
                Text("Notes & Report")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Export")
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
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
    }

    private func exportRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CNFonts.headline)
                        .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    Text(subtitle)
                        .font(CNFonts.caption)
                        .foregroundStyle(CNColors.textSecondary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 18))
            }
            .padding(.vertical, 4)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }

    private func exportFile(content: String, filename: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        sharePayload = SharePayload(items: [fileURL])
    }

    private func exportWithPhotos(content: String, filename: String, photoFilenames: [String]) {
        // Create a unique temp directory for this export
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EAPC-Export-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Build a mapping from internal filename -> readable export name
        var renameMap: [String: String] = [:]
        for note in notesStore.notesWithContent {
            for (i, photoFilename) in note.photoFilenames.enumerated() {
                let baseName = note.presentationTitle.isEmpty ? note.sessionTitle : note.presentationTitle
                let slug = baseName
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                    .prefix(6)
                    .joined(separator: "-")
                    .lowercased()
                let suffix = note.photoFilenames.count > 1 ? "-\(i + 1)" : ""
                let ext = (photoFilename as NSString).pathExtension
                renameMap[photoFilename] = "\(slug)\(suffix).\(ext)"
            }
        }

        // Rewrite photo references in the markdown content
        var updatedContent = content
        for (oldName, newName) in renameMap {
            updatedContent = updatedContent.replacingOccurrences(of: oldName, with: newName)
        }

        // Write the markdown file
        let mdURL = exportDir.appendingPathComponent(filename)
        try? updatedContent.write(to: mdURL, atomically: true, encoding: .utf8)

        var items: [Any] = [mdURL]

        // Copy referenced photos with readable names
        for photoFilename in photoFilenames {
            if let sourceURL = notesStore.photoURL(filename: photoFilename) {
                let exportName = renameMap[photoFilename] ?? photoFilename
                let destURL = exportDir.appendingPathComponent(exportName)
                try? FileManager.default.copyItem(at: sourceURL, to: destURL)
                items.append(destURL)
            }
        }

        sharePayload = SharePayload(items: items)
    }

    private func exportPDF(mode: PDFExportService.Mode) {
        isExportingPDF = true
        Task {
            defer { isExportingPDF = false }
            do {
                let url = try await pdfExporter.export(mode: mode) { filename in
                    // The filename arrives as "photos/X.jpg" or "sketches/Y.png"
                    if filename.hasPrefix("photos/") {
                        let bare = String(filename.dropFirst("photos/".count))
                        return notesStore.photoURL(filename: bare)
                    } else if filename.hasPrefix("sketches/") {
                        let bare = String(filename.dropFirst("sketches/".count))
                        return notesStore.sketchURL(filename: bare)
                    } else {
                        // Fallback: try both
                        return notesStore.sketchOrPhotoURL(filename: filename)
                    }
                }
                await MainActor.run {
                    sharePayload = SharePayload(items: [url])
                }
            } catch {
                print("PDF export failed: \(error)")
            }
        }
    }

    private func exportAllNotes() -> String {
        var md = "# Session Notes — EAPC 2026\n\n"
        for note in notesStore.notesWithContent {
            if !note.presentationTitle.isEmpty {
                md += "## \(note.presentationTitle)\n"
                if !note.presenter.isEmpty {
                    md += "*\(note.presenter)*\n\n"
                }
                md += "*\(note.sessionTitle) · \(note.sessionDate) · \(note.sessionTime) · \(note.sessionVenue)*\n\n"
            } else {
                md += "## \(note.sessionTitle)\n"
                md += "*\(note.sessionDate) · \(note.sessionTime) · \(note.sessionVenue)*\n\n"
            }
            md += note.body
            if !note.photoFilenames.isEmpty {
                md += "\n\n"
                for (i, filename) in note.photoFilenames.enumerated() {
                    md += "![Photo \(i + 1)](\(filename))\n\n"
                }
            }
            md += "\n---\n\n"
        }
        return md
    }

    private func exportPicksMarkdown() -> String {
        let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
        let dayLabels = [
            "2026-05-14": "Thursday, 14 May",
            "2026-05-15": "Friday, 15 May",
            "2026-05-16": "Saturday, 16 May",
        ]

        var md = "# My Picks — EAPC 2026\n\n"
        for date in dates {
            let daySessions = store.myPickedSessions.filter { $0.date == date }
            if daySessions.isEmpty { continue }
            md += "## \(dayLabels[date] ?? date)\n\n"
            for s in daySessions {
                md += "### \(s.startsAt)-\(s.endsAt) · \(s.venue)\n"
                md += "**\(s.title)** (\(s.type.rawValue))\n\n"
                if !s.presentations.isEmpty && s.presentationsCount <= 10 {
                    for p in s.presentations {
                        md += "- \(p.title) — *\(p.presenter)*\n"
                    }
                    md += "\n"
                }
            }
        }
        return md
    }
}

// MARK: - Share Payload

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - ShareSheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
