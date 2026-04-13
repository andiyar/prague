import SwiftUI

struct PeopleListView: View {
    @Environment(ContactStore.self) var contactStore
    @Environment(\.colorScheme) var colorScheme

    @State private var showingAddSheet = false
    @State private var searchText = ""

    private var filtered: [Contact] {
        let sorted = contactStore.sortedContacts
        guard !searchText.isEmpty else { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.name.lowercased().contains(query) ||
            $0.organisation.lowercased().contains(query) ||
            $0.notes.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if contactStore.contacts.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                contactList
            }
        }
        .background(CNColors.background(for: colorScheme))
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(CNColors.navy(for: colorScheme))
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ContactFormView(mode: .add)
        }
        .searchable(text: $searchText, prompt: "Search contacts")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(CNColors.teal(for: colorScheme).opacity(0.4))
            Text("No contacts yet")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            Text("Tap + to add people you meet at the conference.")
                .font(CNFonts.body)
                .foregroundStyle(CNColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var contactList: some View {
        List {
            ForEach(filtered) { contact in
                NavigationLink(value: contact.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.name)
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                        if !contact.organisation.isEmpty {
                            Text(contact.organisation)
                                .font(CNFonts.caption)
                                .foregroundStyle(CNColors.teal(for: colorScheme))
                        }
                        if !contact.metAt.isEmpty {
                            Text(contact.metAt)
                                .font(CNFonts.small)
                                .foregroundStyle(CNColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { offsets in
                // Map filtered offsets back to the store
                let toDelete = offsets.map { filtered[$0] }
                for contact in toDelete {
                    contactStore.delete(contact)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: UUID.self) { contactId in
            if let contact = contactStore.contacts.first(where: { $0.id == contactId }) {
                ContactFormView(mode: .edit(contact))
            }
        }
    }
}
