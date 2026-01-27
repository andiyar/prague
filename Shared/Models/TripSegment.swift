import Foundation

struct TripSegment: Codable, Identifiable {
    let id: Int
    let startTime: Date
    let endTime: Date
    let location: String
    let statusEmoji: String
    let statusText: String
    let kidsText: String
    let lat: Double?
    let lng: Double?
    let flightNumber: String?
    let flightFrom: String?
    let flightTo: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case location
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
        case kidsText = "kids_text"
        case lat, lng
        case flightNumber = "flight_number"
        case flightFrom = "flight_from"
        case flightTo = "flight_to"
    }

    var isFlying: Bool {
        flightNumber != nil
    }

    var coordinate: Coordinate? {
        guard let lat = lat, let lng = lng else { return nil }
        return Coordinate(latitude: lat, longitude: lng)
    }
}

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}
