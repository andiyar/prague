import Foundation

struct Contact: Codable, Identifiable {
    var id: UUID
    var name: String
    var organisation: String
    var email: String
    var phone: String
    var notes: String
    var metAt: String          // free text: session name, "poster hall", etc.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        organisation: String = "",
        email: String = "",
        phone: String = "",
        notes: String = "",
        metAt: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.organisation = organisation
        self.email = email
        self.phone = phone
        self.notes = notes
        self.metAt = metAt
        self.createdAt = createdAt
    }
}
