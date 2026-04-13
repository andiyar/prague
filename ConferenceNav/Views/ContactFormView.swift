import SwiftUI

struct ContactFormView: View {
    enum Mode {
        case add
        case edit(Contact)
    }

    let mode: Mode

    @Environment(ContactStore.self) var contactStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var organisation = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var metAt = ""
    @State private var notes = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Details") {
                    TextField("Name", text: $name)
                    TextField("Organisation", text: $organisation)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("Context") {
                    TextField("Where did you meet?", text: $metAt)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Contact" : "New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveContact()
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if case .edit(let contact) = mode {
                    name = contact.name
                    organisation = contact.organisation
                    email = contact.email
                    phone = contact.phone
                    metAt = contact.metAt
                    notes = contact.notes
                }
            }
        }
    }

    private func saveContact() {
        switch mode {
        case .add:
            let contact = Contact(
                name: name.trimmingCharacters(in: .whitespaces),
                organisation: organisation.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespaces),
                metAt: metAt.trimmingCharacters(in: .whitespaces)
            )
            contactStore.add(contact)
        case .edit(var contact):
            contact.name = name.trimmingCharacters(in: .whitespaces)
            contact.organisation = organisation.trimmingCharacters(in: .whitespaces)
            contact.email = email.trimmingCharacters(in: .whitespaces)
            contact.phone = phone.trimmingCharacters(in: .whitespaces)
            contact.notes = notes.trimmingCharacters(in: .whitespaces)
            contact.metAt = metAt.trimmingCharacters(in: .whitespaces)
            contactStore.update(contact)
        }
    }
}
