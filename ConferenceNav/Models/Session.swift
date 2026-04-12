import Foundation

enum SessionType: String, Codable, CaseIterable {
    case keynote = "Keynote"
    case oral = "Oral"
    case panel = "Panel"
    case poster = "Poster"
    case general = "General"
    case meeting = "Meeting"
    case social = "Social"
    case lunch = "Lunch"
    case tea = "Tea"
}

struct Session: Codable, Identifiable {
    let id: Int
    let day: String
    let date: String
    let title: String
    let type: SessionType
    let venue: String
    let startsAt: String
    let endsAt: String
    let startsAtIso: String
    let endsAtIso: String
    let description: String
    let chairs: [String]
    let presentationsCount: Int
    let presentations: [Presentation]
}

struct Presentation: Codable, Identifiable {
    let id: Int
    let title: String
    let startsAt: String
    let endsAt: String
    let durationMins: Int
    let presenter: String
    let authors: [Author]
}

struct Author: Codable {
    let name: String
    let organisation: String
    let presenting: Bool
}

// MARK: - Helpers

extension Session {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var startDate: Date? {
        Self.isoFormatter.date(from: startsAtIso)
    }

    var endDate: Date? {
        Self.isoFormatter.date(from: endsAtIso)
    }

    var dayLabel: String {
        switch date {
        case "2026-05-14": return "Thu 14 May"
        case "2026-05-15": return "Fri 15 May"
        case "2026-05-16": return "Sat 16 May"
        default: return date
        }
    }

    var timeSlot: String {
        "\(startsAt) - \(endsAt)"
    }

    var isBrowseable: Bool {
        switch type {
        case .tea, .lunch: return false
        default: return true
        }
    }

    func conflicts(with other: Session) -> Bool {
        guard date == other.date,
              let s1 = startDate, let e1 = endDate,
              let s2 = other.startDate, let e2 = other.endDate else {
            return false
        }
        return s1 < e2 && s2 < e1
    }
}

extension SessionType {
    static var filterableTypes: [SessionType] {
        [.keynote, .oral, .panel, .poster, .general, .meeting]
    }
}
