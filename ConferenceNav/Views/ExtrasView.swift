import SwiftUI

struct ExtrasView: View {
    @Environment(ContactStore.self) var contactStore
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            List {
                // People
                NavigationLink(value: "people") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("People")
                                .font(CNFonts.headline)
                                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            Text("\(contactStore.contacts.count) contacts")
                                .font(CNFonts.caption)
                                .foregroundStyle(CNColors.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.rectangle.stack")
                            .foregroundStyle(CNColors.teal(for: colorScheme))
                            .font(.system(size: 20))
                    }
                    .padding(.vertical, 6)
                }

                // Session Notes (V2)
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session Notes")
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                        Text("Coming soon")
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                } icon: {
                    Image(systemName: "note.text")
                        .foregroundStyle(CNColors.textSecondary.opacity(0.5))
                        .font(.system(size: 20))
                }
                .padding(.vertical, 6)
                .opacity(0.5)

                // Export
                Section {
                    NavigationLink(value: "export") {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export")
                                    .font(CNFonts.headline)
                                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                Text("Share contacts or picks")
                                    .font(CNFonts.caption)
                                    .foregroundStyle(CNColors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(CNColors.navy(for: colorScheme))
                                .font(.system(size: 20))
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Extras")
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "people":
                    PeopleListView()
                case "export":
                    ExportView()
                default:
                    EmptyView()
                }
            }
        }
    }
}
