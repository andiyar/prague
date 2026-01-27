import Foundation
import CoreLocation

/// Represents Ben's current status, derived from either a schedule segment or manual override
struct CurrentStatus {
    let emoji: String
    let text: String
    let kidsText: String
    let note: String?
    let coordinate: CLLocationCoordinate2D?
    let isOverride: Bool
    let updatedAt: Date?

    // Flight info (if currently flying)
    let flightNumber: String?
    let flightFrom: String?
    let flightTo: String?
    let flightStartTime: Date?
    let flightEndTime: Date?

    var isFlying: Bool {
        flightNumber != nil
    }

    var flightProgress: Double? {
        guard let start = flightStartTime, let end = flightEndTime else { return nil }
        let now = Date()
        guard now >= start else { return 0 }
        guard now < end else { return 1 }
        return (now.timeIntervalSince(start)) / (end.timeIntervalSince(start))
    }

    init(from segment: TripSegment) {
        self.emoji = segment.statusEmoji
        self.text = segment.statusText
        self.kidsText = segment.kidsText
        self.note = nil
        self.isOverride = false
        self.updatedAt = nil

        if let lat = segment.lat, let lng = segment.lng {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            self.coordinate = nil
        }

        self.flightNumber = segment.flightNumber
        self.flightFrom = segment.flightFrom
        self.flightTo = segment.flightTo
        self.flightStartTime = segment.isFlying ? segment.startTime : nil
        self.flightEndTime = segment.isFlying ? segment.endTime : nil
    }

    init(from override: StatusOverride) {
        self.emoji = override.statusEmoji
        self.text = override.statusText
        self.kidsText = override.kidsText
        self.note = override.note
        self.isOverride = true
        self.updatedAt = override.createdAt

        if let lat = override.lat, let lng = override.lng {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            self.coordinate = nil
        }

        self.flightNumber = nil
        self.flightFrom = nil
        self.flightTo = nil
        self.flightStartTime = nil
        self.flightEndTime = nil
    }

    /// Default status when trip hasn't started
    static let preTrip = CurrentStatus(
        emoji: "📅",
        text: "Trip starts soon!",
        kidsText: "Daddy's trip is coming up!",
        note: nil,
        coordinate: CLLocationCoordinate2D(latitude: -34.4278, longitude: 150.8931), // Wollongong
        isOverride: false,
        updatedAt: nil,
        flightNumber: nil,
        flightFrom: nil,
        flightTo: nil,
        flightStartTime: nil,
        flightEndTime: nil
    )

    /// Default status when trip has ended
    static let postTrip = CurrentStatus(
        emoji: "🏠",
        text: "Back home!",
        kidsText: "Daddy's home!",
        note: nil,
        coordinate: CLLocationCoordinate2D(latitude: -34.4278, longitude: 150.8931), // Wollongong
        isOverride: false,
        updatedAt: nil,
        flightNumber: nil,
        flightFrom: nil,
        flightTo: nil,
        flightStartTime: nil,
        flightEndTime: nil
    )

    private init(
        emoji: String,
        text: String,
        kidsText: String,
        note: String?,
        coordinate: CLLocationCoordinate2D?,
        isOverride: Bool,
        updatedAt: Date?,
        flightNumber: String?,
        flightFrom: String?,
        flightTo: String?,
        flightStartTime: Date?,
        flightEndTime: Date?
    ) {
        self.emoji = emoji
        self.text = text
        self.kidsText = kidsText
        self.note = note
        self.coordinate = coordinate
        self.isOverride = isOverride
        self.updatedAt = updatedAt
        self.flightNumber = flightNumber
        self.flightFrom = flightFrom
        self.flightTo = flightTo
        self.flightStartTime = flightStartTime
        self.flightEndTime = flightEndTime
    }
}
