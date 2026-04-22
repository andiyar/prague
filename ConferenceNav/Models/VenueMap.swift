import SwiftUI

// MARK: - Floors

/// One physical level of the O2 Universum.
enum VenueFloor: String, CaseIterable, Hashable, Identifiable {
    case floor0
    case floor1
    case floor2
    case floor3
    case meetingHub

    var id: String { rawValue }

    /// Asset Catalog image name for the floor plan JPG.
    var imageName: String {
        switch self {
        case .floor0:     return "Floor 0"
        case .floor1:     return "Floor 1"
        case .floor2:     return "Floor 2"
        case .floor3:     return "Floor 3"
        case .meetingHub: return "Meeting Hub"
        }
    }

    /// User-facing name, e.g. shown in the floor switcher.
    var displayName: String {
        switch self {
        case .floor0:     return "Floor 0"
        case .floor1:     return "Floor 1"
        case .floor2:     return "Floor 2"
        case .floor3:     return "Floor 3"
        case .meetingHub: return "Meeting Hub"
        }
    }

    /// Short label for the segmented floor switcher.
    var shortLabel: String {
        switch self {
        case .floor0:     return "0"
        case .floor1:     return "1"
        case .floor2:     return "2"
        case .floor3:     return "3"
        case .meetingHub: return "Hub"
        }
    }

    /// Order shown in the floor switcher (low → high, hub last).
    var sortOrder: Int {
        switch self {
        case .floor0:     return 0
        case .floor1:     return 1
        case .floor2:     return 2
        case .floor3:     return 3
        case .meetingHub: return 4
        }
    }
}

// MARK: - Rooms

/// A room/hall the user might find a session in.
struct VenueRoom: Hashable, Identifiable {
    /// Matches the `venue` string in `programme.json` exactly (case-sensitive).
    let code: String

    /// Prettier display form, e.g. "Hall C2" instead of "C2".
    let displayName: String

    /// Which floor plan to show.
    let floor: VenueFloor

    /// Pin position in normalised image coords (0.0 – 1.0, top-left origin).
    /// Refined in Task 6 using the debug crosshair tool.
    let pinPosition: CGPoint

    var id: String { code }
}

// MARK: - Catalog

/// Single source of truth mapping `Session.venue` → `VenueRoom`.
enum VenueMapCatalog {

    /// Keyed on the exact `venue` string from `programme.json`.
    /// Pin positions are placeholders — refined in Task 6.
    static let rooms: [String: VenueRoom] = [
        // Floor 3 — east wing (C and D halls)
        "C1": VenueRoom(code: "C1", displayName: "Hall C1", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "C2": VenueRoom(code: "C2", displayName: "Hall C2", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "C3": VenueRoom(code: "C3", displayName: "Hall C3", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "D3": VenueRoom(code: "D3", displayName: "Hall D3", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "D4": VenueRoom(code: "D4", displayName: "Hall D4", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "D7": VenueRoom(code: "D7", displayName: "Hall D7", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "D8": VenueRoom(code: "D8", displayName: "Hall D8", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "D9": VenueRoom(code: "D9", displayName: "Hall D9", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),

        // Hall A — floor TBD in Task 6 (placeholder: floor1)
        "Hall A": VenueRoom(code: "Hall A", displayName: "Hall A", floor: .floor1, pinPosition: CGPoint(x: 0.5, y: 0.5)),

        // Posters Hall and Refreshment area — locations TBD in Task 6.
        // If they cannot be placed on any floor plan, REMOVE them from this dictionary
        // (graceful fallback: thumbnail silently disappears for those sessions).
        "Printed Posters Hall":     VenueRoom(code: "Printed Posters Hall", displayName: "Printed Posters Hall", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
        "Refreshment & lunch area": VenueRoom(code: "Refreshment & lunch area", displayName: "Refreshment & Lunch", floor: .floor3, pinPosition: CGPoint(x: 0.5, y: 0.5)),
    ]

    /// Lookup by the exact `Session.venue` string. Returns nil for unknown venues.
    static func room(for venue: String) -> VenueRoom? {
        rooms[venue]
    }

    /// All rooms on a given floor.
    static func rooms(on floor: VenueFloor) -> [VenueRoom] {
        rooms.values.filter { $0.floor == floor }
    }
}
