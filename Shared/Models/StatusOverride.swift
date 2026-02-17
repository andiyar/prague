import Foundation

struct StatusOverride: Codable, Identifiable {
    let id: Int
    let createdAt: Date
    let expiresAt: Date
    let statusEmoji: String
    let statusText: String
    let kidsText: String
    let note: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
        case kidsText = "kids_text"
        case note, lat, lng
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var coordinate: Coordinate? {
        guard let lat = lat, let lng = lng else { return nil }
        return Coordinate(latitude: lat, longitude: lng)
    }
}

struct StatusOverrideInsert: Codable {
    let id: Int
    let statusEmoji: String
    let statusText: String
    let kidsText: String
    let note: String?
    let lat: Double?
    let lng: Double?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
        case kidsText = "kids_text"
        case note, lat, lng
        case expiresAt = "expires_at"
    }
}
