import SwiftUI

/// One numbered pin to render on the My Day overlay.
/// May represent multiple back-to-back sessions in the same room.
struct MyDayPin: Identifiable, Equatable {
    let id: String           // composed of session ids, e.g. "12,45"
    let label: String        // "1", "2", "1-2"
    let room: VenueRoom
    let sessions: [Session]  // chronological order

    var earliestStart: String { sessions.first?.startsAt ?? "" }

    static func == (lhs: MyDayPin, rhs: MyDayPin) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.room.code == rhs.room.code
    }
}

/// Pure-data helpers. SwiftUI rendering happens in `MyDayOverlayView`.
enum MyDayOverlay {

    /// Pick all `myPicks` sessions on the given conference day, sort by start
    /// time, drop any without a known venue, then merge consecutive picks
    /// that share a room into single combined pins.
    ///
    /// Numbering reflects chronological order of *picks*, not of pins:
    /// if picks 2 and 3 share a room, the merged pin is labelled "2-3".
    static func pins(
        for day: String,
        sessions: [Session],
        picks: Set<Int>
    ) -> [MyDayPin] {
        // 1. Filter to today's picked sessions, with a known venue
        let todayPicks = sessions
            .filter { $0.date == day && picks.contains($0.id) }
            .compactMap { session -> (Session, VenueRoom)? in
                guard let room = VenueMapCatalog.room(for: session.venue) else { return nil }
                return (session, room)
            }
            .sorted { $0.0.startsAt < $1.0.startsAt }

        // 2. Number them 1..N
        let numbered = todayPicks.enumerated().map { (idx, pair) -> (Int, Session, VenueRoom) in
            (idx + 1, pair.0, pair.1)
        }

        // 3. Merge consecutive entries that share a room
        var merged: [MyDayPin] = []
        var buffer: [(Int, Session, VenueRoom)] = []

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            let nums = buffer.map { String($0.0) }
            let label = nums.count == 1 ? nums[0] : "\(nums.first!)-\(nums.last!)"
            let id = buffer.map { String($0.1.id) }.joined(separator: ",")
            let pin = MyDayPin(
                id: id,
                label: label,
                room: buffer.first!.2,
                sessions: buffer.map { $0.1 }
            )
            merged.append(pin)
            buffer.removeAll()
        }

        for entry in numbered {
            if let last = buffer.last, last.2.code == entry.2.code {
                buffer.append(entry)
            } else {
                flushBuffer()
                buffer.append(entry)
            }
        }
        flushBuffer()

        return merged
    }
}

/// Renders numbered pins for picks on a given floor.
/// Tapping a pin opens a popover with session details.
struct MyDayOverlayView: View {
    let pins: [MyDayPin]
    let floor: VenueFloor
    let displayedImageRect: CGRect

    @State private var selectedPin: MyDayPin?

    var body: some View {
        ZStack {
            ForEach(pins.filter { $0.room.floor == floor }) { pin in
                Button {
                    selectedPin = pin
                } label: {
                    VenueMapPin(label: pin.label, size: 32)
                }
                .buttonStyle(.plain)
                .position(
                    x: displayedImageRect.minX + pin.room.pinPosition.x * displayedImageRect.width,
                    y: displayedImageRect.minY + pin.room.pinPosition.y * displayedImageRect.height
                )
            }
        }
        .sheet(item: $selectedPin) { pin in
            MyDayPinDetailSheet(pin: pin)
                .presentationDetents([.medium])
        }
    }
}

/// Bottom-sheet popover when a numbered pin is tapped.
struct MyDayPinDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let pin: MyDayPin

    var body: some View {
        NavigationStack {
            List {
                ForEach(pin.sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(CNFonts.headline)
                        HStack(spacing: 8) {
                            Text("\(session.startsAt)–\(session.endsAt)")
                                .font(CNFonts.caption)
                                .foregroundStyle(CNColors.textSecondary)
                            Text("·")
                                .foregroundStyle(CNColors.textSecondary)
                            Text(session.type.rawValue)
                                .font(CNFonts.caption)
                                .foregroundStyle(CNColors.typeBadgeColor(for: session.type, scheme: colorScheme))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("\(pin.room.displayName) · #\(pin.label)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
