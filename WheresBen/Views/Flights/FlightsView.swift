import SwiftUI

struct FlightsView: View {
    @EnvironmentObject var tripData: TripDataService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Outbound Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Outbound")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    ForEach(Array(tripData.outboundFlights.enumerated()), id: \.element.id) { index, flight in
                        FlightCard(segment: flight)

                        // Layover indicator between flights
                        if index < tripData.outboundFlights.count - 1,
                           let layover = layoverInfo(after: flight) {
                            LayoverIndicator(duration: layover.duration, location: layover.location)
                        }
                    }
                }

                // Return Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Return")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    ForEach(Array(tripData.returnFlights.enumerated()), id: \.element.id) { index, flight in
                        FlightCard(segment: flight)

                        // Layover indicator between flights
                        if index < tripData.returnFlights.count - 1,
                           let layover = layoverInfo(after: flight) {
                            LayoverIndicator(duration: layover.duration, location: layover.location)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.cozyBackground)
    }

    private func layoverInfo(after flight: TripSegment) -> (duration: String, location: String)? {
        // Find the next segment after this flight
        guard let index = tripData.segments.firstIndex(where: { $0.id == flight.id }),
              index + 1 < tripData.segments.count else {
            return nil
        }

        let nextSegment = tripData.segments[index + 1]

        // Check if it's a layover (not a flight)
        guard !nextSegment.isFlying else { return nil }

        let duration = nextSegment.endTime.timeIntervalSince(nextSegment.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        let durationString = minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"

        // Extract location name from the segment
        let location = nextSegment.location
            .replacingOccurrences(of: " Airport", with: "")

        return (durationString, location)
    }
}

struct LayoverIndicator: View {
    let duration: String
    let location: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.cozyAccent.opacity(0.3))
                .frame(width: 2, height: 30)
                .padding(.leading, 20)

            Text("\(duration) layover in \(location)")
                .font(.cozyCaption)
                .foregroundColor(.cozyTextSecondary)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        FlightsView()
            .navigationTitle("Flights")
    }
    .environmentObject(TripDataService.shared)
}
