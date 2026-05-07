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
    /// Pin positions measured from the bundled floor plan JPGs (1050×955 for
    /// Floor 3, 1050×847 for Floor 0). Coordinates are normalised (0–1,
    /// top-left origin) and target the centre of each room's labelled
    /// rectangle. Verifiable visually with the in-app DEBUG crosshair tool —
    /// small nudges welcome.
    static let rooms: [String: VenueRoom] = [
        // Floor 3 — C column (left), D row (middle/bottom).
        // C3 / C2 / C1 stack vertically along the far left, top → bottom.
        "C3": VenueRoom(code: "C3", displayName: "Hall C3", floor: .floor3, pinPosition: CGPoint(x: 0.08, y: 0.43)),
        "C2": VenueRoom(code: "C2", displayName: "Hall C2", floor: .floor3, pinPosition: CGPoint(x: 0.08, y: 0.51)),
        "C1": VenueRoom(code: "C1", displayName: "Hall C1", floor: .floor3, pinPosition: CGPoint(x: 0.08, y: 0.59)),
        // D3 / D4 sit in the middle-row band, right of centre stage area.
        "D3": VenueRoom(code: "D3", displayName: "Hall D3", floor: .floor3, pinPosition: CGPoint(x: 0.60, y: 0.66)),
        "D4": VenueRoom(code: "D4", displayName: "Hall D4", floor: .floor3, pinPosition: CGPoint(x: 0.70, y: 0.66)),
        // D7 / D8 / D9 sit along the bottom row.
        // Order left-to-right in the bottom row: D10, D9, D8, OFFICE, [stage], OFFICE, D7, D6, D5.
        "D9": VenueRoom(code: "D9", displayName: "Hall D9", floor: .floor3, pinPosition: CGPoint(x: 0.28, y: 0.84)),
        "D8": VenueRoom(code: "D8", displayName: "Hall D8", floor: .floor3, pinPosition: CGPoint(x: 0.35, y: 0.84)),
        "D7": VenueRoom(code: "D7", displayName: "Hall D7", floor: .floor3, pinPosition: CGPoint(x: 0.66, y: 0.84)),

        // Hall A is the main blue hall on Floor 0 (clearly labelled "Hall A").
        // Floor 1 shows the upper view of the same arena but is unlabeled,
        // so Floor 0 is the canonical map for Hall A.
        "Hall A": VenueRoom(code: "Hall A", displayName: "Hall A", floor: .floor0, pinPosition: CGPoint(x: 0.45, y: 0.51)),

        // Printed Posters Hall and Refreshment & lunch area are not labelled on
        // any of the 5 floor plans (Floor 0–3 + Meeting Hub). Per Task 6 spec,
        // we omit them so the graceful fallback in the UI silently hides the
        // thumbnail for those sessions instead of showing a wrong location.
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
