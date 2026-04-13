import SwiftUI

@Observable
class ContactStore {
    private(set) var contacts: [Contact] = []

    private let userKey: String

    init(userId: String) {
        self.userKey = "conferenceContacts_\(userId)"
        load()
    }

    var sortedContacts: [Contact] {
        contacts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func add(_ contact: Contact) {
        contacts.append(contact)
        save()
    }

    func update(_ contact: Contact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            save()
        }
    }

    func delete(_ contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        save()
    }

    func deleteAt(offsets: IndexSet) {
        let sorted = sortedContacts
        for index in offsets {
            let contact = sorted[index]
            contacts.removeAll { $0.id == contact.id }
        }
        save()
    }

    // MARK: - Export

    func exportAsCSV() -> String {
        var csv = "Name,Organisation,Email,Phone,Met At,Notes\n"
        for c in sortedContacts {
            csv += "\(csvEscape(c.name)),\(csvEscape(c.organisation)),\(csvEscape(c.email)),\(csvEscape(c.phone)),\(csvEscape(c.metAt)),\(csvEscape(c.notes))\n"
        }
        return csv
    }

    func exportAsMarkdown() -> String {
        var md = "# Conference Contacts — EAPC 2026\n\n"
        if contacts.isEmpty {
            md += "No contacts saved yet.\n"
            return md
        }
        for c in sortedContacts {
            md += "## \(c.name)\n"
            if !c.organisation.isEmpty { md += "- **Organisation:** \(c.organisation)\n" }
            if !c.email.isEmpty { md += "- **Email:** \(c.email)\n" }
            if !c.phone.isEmpty { md += "- **Phone:** \(c.phone)\n" }
            if !c.metAt.isEmpty { md += "- **Met at:** \(c.metAt)\n" }
            if !c.notes.isEmpty { md += "- **Notes:** \(c.notes)\n" }
            md += "\n"
        }
        return md
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let decoded = try? JSONDecoder().decode([Contact].self, from: data) else {
            return
        }
        contacts = decoded
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
