import Foundation

enum StatusAudience: String, Codable, CaseIterable, Identifiable {
    case main, kids, both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: return "Family"
        case .kids: return "Kids"
        case .both: return "Both"
        }
    }

    var icon: String {
        switch self {
        case .main: return "heart.fill"
        case .kids: return "face.smiling.fill"
        case .both: return "person.2.fill"
        }
    }

    var showsOnMain: Bool { self == .main || self == .both }
    var showsOnKids: Bool { self == .kids || self == .both }
}

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
    let photoUrl: String?
    let audience: StatusAudience?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
        case kidsText = "kids_text"
        case note, lat, lng
        case photoUrl = "photo_url"
        case audience
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var coordinate: Coordinate? {
        guard let lat = lat, let lng = lng else { return nil }
        return Coordinate(latitude: lat, longitude: lng)
    }

    var effectiveAudience: StatusAudience {
        audience ?? .both
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
    let photoUrl: String?
    let audience: String

    enum CodingKeys: String, CodingKey {
        case id
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
        case kidsText = "kids_text"
        case note, lat, lng
        case expiresAt = "expires_at"
        case photoUrl = "photo_url"
        case audience
    }
}
