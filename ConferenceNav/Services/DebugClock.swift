import Foundation
import Observation

/// Abstracts "now"/"today" so debug builds can simulate conference dates.
///
/// In release builds this is a no-op wrapper around `Date()` — there is no
/// debug UI and no extra code path. In debug builds, `simulatedDate` can be
/// set to `2026-05-14`, `2026-05-15`, or `2026-05-16` (start-of-day in the
/// venue's timezone, Europe/Prague) and `currentDay` will return that date
/// string so the My Day overlay shows the picks for that conference day.
@Observable
final class DebugClock {
    static let shared = DebugClock()

    #if DEBUG
    /// When non-nil, drives `currentDay` to a chosen conference date.
    var simulatedDate: SimulatedConferenceDay? = nil
    #endif

    /// `Session.date` string for the current day, e.g. `"2026-05-14"`.
    /// Falls back to today's real date in any non-debug build, or when no
    /// simulated date is set.
    var currentDay: String {
        #if DEBUG
        if let simulated = simulatedDate {
            return simulated.dateString
        }
        #endif
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Prague") ?? .current
        return formatter.string(from: Date())
    }
}

/// The three conference days available for simulation.
enum SimulatedConferenceDay: String, CaseIterable, Identifiable {
    case may14 = "2026-05-14"
    case may15 = "2026-05-15"
    case may16 = "2026-05-16"

    var id: String { rawValue }
    var dateString: String { rawValue }
    var displayName: String {
        switch self {
        case .may14: return "Thu 14 May"
        case .may15: return "Fri 15 May"
        case .may16: return "Sat 16 May"
        }
    }
}
