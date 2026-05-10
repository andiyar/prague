import SwiftUI

struct ExtrasView: View {
    @Environment(ContactStore.self) var contactStore
    @Environment(ConferenceStore.self) var store
    @Environment(NotesStore.self) var notesStore
    @Environment(\.colorScheme) var colorScheme

    // Venue map (and debug variant) present as sheets, not navigation pushes,
    // because VenueMapView wraps its body in its own NavigationStack — pushing
    // it via navigationDestination created nested NavigationStacks that
    // SwiftUI auto-pops, leaving the parent stack in a broken state.
    @State private var showingVenueMap = false
    #if DEBUG
    @State private var showingVenueMapDebug = false
    #endif

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

                // Session Notes
                NavigationLink(value: "notes") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session Notes")
                                .font(CNFonts.headline)
                                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            Text("\(notesStore.notesWithContent.count) notes")
                                .font(CNFonts.caption)
                                .foregroundStyle(CNColors.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "note.text")
                            .foregroundStyle(CNColors.teal(for: colorScheme))
                            .font(.system(size: 20))
                    }
                    .padding(.vertical, 6)
                }

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

                Section {
                    Button {
                        showingVenueMap = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Venue Map")
                                    .font(CNFonts.headline)
                                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                Text("O2 Universum floor plans")
                                    .font(CNFonts.caption)
                                    .foregroundStyle(CNColors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "map")
                                .foregroundStyle(CNColors.gold(for: colorScheme))
                                .font(.system(size: 20))
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }

                #if DEBUG
                Section {
                    Button {
                        showingVenueMapDebug = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Venue Map Debug")
                                    .font(CNFonts.headline)
                                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                Text("Simulate dates · pin crosshairs")
                                    .font(CNFonts.caption)
                                    .foregroundStyle(CNColors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "ladybug")
                                .foregroundStyle(CNColors.red(for: colorScheme))
                                .font(.system(size: 20))
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Debug")
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .cnPadMaxWidth(CNLayout.MaxWidth.tabContent)
            .navigationTitle("Extras")
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "people":
                    PeopleListView()
                case "export":
                    ExportView()
                case "notes":
                    NoteListView()
                default:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showingVenueMap) {
                // VenueMapView no longer owns a NavigationStack — wrap it
                // here so the title bar / Done button / toolbar render in
                // the sheet.
                NavigationStack {
                    VenueMapView(focus: .browse(.floor3))
                }
            }
            #if DEBUG
            .sheet(isPresented: $showingVenueMapDebug) {
                NavigationStack {
                    VenueMapDebugView()
                }
            }
            #endif
        }
    }
}
