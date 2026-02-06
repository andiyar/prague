import SwiftUI

struct WhereIsBenView: View {
    @EnvironmentObject var tripData: TripDataService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if tripData.isLoading {
                    ProgressView()
                        .padding(40)
                } else {
                    // Title
                    Text("Where's Ben?")
                        .font(.cozyLargeTitle)
                        .foregroundColor(.cozyText)

                    // Status Card
                    StatusCard()

                    // Map Card
                    MapCard()

                    // Quick Info Row
                    QuickInfoRow()

                    // Next Up Card
                    NextUpCard()
                }
            }
            .padding()
        }
        .background(Color.cozyBackground)
        .refreshable {
            await tripData.refresh()
        }
    }
}

// MARK: - Quick Info Row

struct QuickInfoRow: View {
    @EnvironmentObject var tripData: TripDataService

    var body: some View {
        HStack(spacing: 12) {
            // Home time
            QuickInfoItem(
                icon: "house.fill",
                title: "Home",
                value: homeTimeString
            )

            // Ben's local time
            QuickInfoItem(
                icon: "person.fill",
                title: benLocationName,
                value: benTimeString
            )

            // Countdown
            QuickInfoItem(
                icon: "clock.fill",
                title: "Home in",
                value: countdownString
            )
        }
    }

    private var homeTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        return formatter.string(from: tripData.effectiveNow)
    }

    private var benTimezone: TimeZone {
        if let coord = tripData.currentStatus.coordinate {
            if coord.latitude < 0 {
                return TimeZone(identifier: "Australia/Sydney")!
            } else if coord.latitude > 20 && coord.latitude < 30 {
                return TimeZone(identifier: "Asia/Dubai")!
            } else {
                return TimeZone(identifier: "Europe/Prague")!
            }
        }
        return TimeZone(identifier: "Australia/Sydney")!
    }

    private var benLocationName: String {
        if let coord = tripData.currentStatus.coordinate {
            if coord.latitude < 0 {
                return "Sydney"
            } else if coord.latitude > 20 && coord.latitude < 30 {
                return "Dubai"
            } else {
                return "Prague"
            }
        }
        return "Ben"
    }

    private var benTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = benTimezone
        return formatter.string(from: tripData.effectiveNow)
    }

    private var countdownString: String {
        guard let seconds = tripData.timeUntilHome else { return "Home!" }

        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600

        if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            return "\(hours)h"
        }
    }
}

struct QuickInfoItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.cozyAccent)

            Text(value)
                .font(.cozyHeadline)
                .foregroundColor(.cozyText)

            Text(title)
                .font(.cozyCaption)
                .foregroundColor(.cozyTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cozyCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Next Up Card

struct NextUpCard: View {
    @EnvironmentObject var tripData: TripDataService

    var body: some View {
        if let nextEvent = nextEvent {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.cozyAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Next")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)

                    Text(nextEvent)
                        .font(.cozyBody)
                        .foregroundColor(.cozyText)
                }

                Spacer()
            }
            .padding()
            .background(Color.cozyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var nextEvent: String? {
        let now = tripData.effectiveNow

        // Find next segment
        guard let nextSegment = tripData.segments.first(where: { $0.startTime > now }) else {
            return nil
        }

        let timeUntil = nextSegment.startTime.timeIntervalSince(now)
        let hours = Int(timeUntil) / 3600
        let minutes = (Int(timeUntil) % 3600) / 60

        let timeString: String
        if hours > 24 {
            let days = hours / 24
            timeString = "in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            timeString = "in \(hours)h \(minutes)m"
        } else {
            timeString = "in \(minutes)m"
        }

        if nextSegment.isFlying {
            return "Flight \(nextSegment.flightNumber ?? "") departs \(timeString)"
        } else {
            return "\(nextSegment.statusText) \(timeString)"
        }
    }
}

#Preview {
    NavigationStack {
        WhereIsBenView()
    }
    .environmentObject(TripDataService.shared)
}
