import SwiftUI

struct ExportView: View {
    @Environment(ContactStore.self) var contactStore
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var showingShareSheet = false
    @State private var exportURL: URL?

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
                Text("Session Notes export coming in V2")
                    .font(CNFonts.caption)
                    .foregroundStyle(CNColors.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Export")
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
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
        exportURL = fileURL
        showingShareSheet = true
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

// MARK: - ShareSheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
