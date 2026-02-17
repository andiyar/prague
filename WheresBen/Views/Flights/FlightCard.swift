import SwiftUI

struct FlightCard: View {
    let segment: TripSegment
    @EnvironmentObject var tripData: TripDataService
    @State private var isExpanded = false

    private var status: FlightStatus {
        tripData.flightStatus(for: segment)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary row (always visible)
            Button {
                withAnimation(.gentleBounce) {
                    isExpanded.toggle()
                }
            } label: {
                summaryRow
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                expandedDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.cozyCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(status.isActive ? Color.cozyAccent : Color.cozyCardBorder, lineWidth: status.isActive ? 2 : 1)
        )
        .shadow(color: status.isActive ? Color.cozyAccent.opacity(0.3) : .black.opacity(0.06), radius: status.isActive ? 12 : 8, x: 0, y: 4)
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .glow(color: status.isActive ? .cozyAccent : .clear, radius: 5)

            // Flight number
            Text(segment.flightNumber ?? "")
                .font(.cozyHeadline)
                .foregroundColor(.cozyText)

            Text("·")
                .foregroundColor(.cozyTextSecondary)

            // Route
            Text("\(airportName(segment.flightFrom)) → \(airportName(segment.flightTo))")
                .font(.cozyBody)
                .foregroundColor(.cozyTextSecondary)

            Spacer()

            // Expand chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(.cozyTextSecondary)
        }
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)

            // Time info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Departs")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                    Text(formattedTime(segment.startTime, timezone: departureTimezone))
                        .font(.cozyBody)
                        .foregroundColor(.cozyText)
                    Text(formattedDate(segment.startTime, timezone: departureTimezone))
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(flightDuration)
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                    Image(systemName: "airplane")
                        .foregroundColor(.cozyAccent)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Arrives")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                    Text(formattedTime(segment.endTime, timezone: arrivalTimezone))
                        .font(.cozyBody)
                        .foregroundColor(.cozyText)
                    Text(formattedDate(segment.endTime, timezone: arrivalTimezone))
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                }
            }

            // Progress bar (if in progress)
            if case .inProgress(let progress) = status {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.cozyCardBorder)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.cozyAccent, .cozyAccent.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text(remainingTime)
                        .font(.cozyCaption)
                        .foregroundColor(.cozyAccent)
                }
            }

            // Status text
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.cozyCaption)
                    .foregroundColor(.cozyTextSecondary)
                Spacer()
            }

            // Track live button
            if case .inProgress = status {
                Link(destination: flightRadarURL) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Track Live")
                    }
                    .font(.cozyCaption)
                    .foregroundColor(.cozyAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cozyAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch status {
        case .upcoming: return .gray
        case .inProgress: return .cozyAccent
        case .complete: return .cozySage
        }
    }

    private var statusIcon: String {
        switch status {
        case .upcoming: return "calendar"
        case .inProgress: return "airplane"
        case .complete: return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        switch status {
        case .upcoming: return "Scheduled"
        case .inProgress: return "In Flight"
        case .complete: return "Complete"
        }
    }

    private var remainingTime: String {
        let now = tripData.effectiveNow
        let remaining = segment.endTime.timeIntervalSince(now)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        }
        return "\(minutes)m remaining"
    }

    private var flightDuration: String {
        let duration = segment.endTime.timeIntervalSince(segment.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var departureTimezone: TimeZone {
        switch segment.flightFrom {
        case "SYD": return TimeZone(identifier: "Australia/Sydney")!
        case "DXB": return TimeZone(identifier: "Asia/Dubai")!
        case "PRG": return TimeZone(identifier: "Europe/Prague")!
        default: return .current
        }
    }

    private var arrivalTimezone: TimeZone {
        switch segment.flightTo {
        case "SYD": return TimeZone(identifier: "Australia/Sydney")!
        case "DXB": return TimeZone(identifier: "Asia/Dubai")!
        case "PRG": return TimeZone(identifier: "Europe/Prague")!
        default: return .current
        }
    }

    private var flightRadarURL: URL {
        URL(string: "https://www.flightradar24.com/\(segment.flightNumber ?? "")")!
    }

    private func airportName(_ code: String?) -> String {
        switch code {
        case "SYD": return "Sydney"
        case "DXB": return "Dubai"
        case "PRG": return "Prague"
        default: return code ?? ""
        }
    }

    private func formattedTime(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }

    private func formattedDate(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color.cozyBackground.ignoresSafeArea()

        VStack {
            FlightCard(segment: TripSegment(
                id: 1,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600 * 14),
                location: "In flight",
                statusEmoji: "✈️",
                statusText: "Flying",
                kidsText: "Daddy's on the plane!",
                lat: nil,
                lng: nil,
                flightNumber: "EK417",
                flightFrom: "SYD",
                flightTo: "DXB"
            ))
            .padding()
        }
    }
    .environmentObject(TripDataService.shared)
}
