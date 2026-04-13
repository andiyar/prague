import SwiftUI

struct ExportView: View {
    @Environment(ContactStore.self) var contactStore
    @Environment(ConferenceStore.self) var store
    @Environment(NotesStore.self) var notesStore
    @Environment(\.colorScheme) var colorScheme

    @State private var shareItem: URL?

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
                    disabled: store.myPickedSessions.isEmpty
                ) {
                    exportFile(
                        content: notesStore.exportConferenceReport(pickedSessions: store.myPickedSessions),
                        filename: "EAPC-2026-Conference-Report.md"
                    )
                }

                exportRow(
                    title: "All Notes (Markdown)",
                    subtitle: "\(notesStore.notesWithContent.count) notes",
                    icon: "note.text",
                    iconColor: CNColors.teal(for: colorScheme),
                    disabled: notesStore.notesWithContent.isEmpty
                ) {
                    exportFile(
                        content: exportAllNotes(),
                        filename: "EAPC-2026-Notes.md"
                    )
                }
            } header: {
                Text("Notes & Report")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Export")
        .sheet(item: $shareItem) { url in
            ShareSheet(items: [url])
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
        shareItem = fileURL
    }

    private func exportAllNotes() -> String {
        var md = "# Session Notes — EAPC 2026\n\n"
        for note in notesStore.notesWithContent {
            md += "## \(note.sessionTitle)\n"
            md += "*\(note.sessionDate) · \(note.sessionTime) · \(note.sessionVenue)*\n\n"
            md += note.body
            md += "\n\n---\n\n"
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

// MARK: - URL + Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - ShareSheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
