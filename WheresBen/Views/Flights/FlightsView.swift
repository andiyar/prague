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

                    ForEach(tripData.outboundFlights, id: \.id) { flight in
                        FlightCard(segment: flight)
                    }

                    // Layover indicator
                    if let layover = layoverDuration(after: tripData.outboundFlights.first) {
                        LayoverIndicator(duration: layover, location: "Dubai")
                    }
                }

                // Return Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Return")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    ForEach(tripData.returnFlights, id: \.id) { flight in
                        FlightCard(segment: flight)
                    }

                    // Layover indicator
                    if tripData.returnFlights.count >= 2 {
                        if let layover = layoverDuration(after: tripData.returnFlights.first) {
                            LayoverIndicator(duration: layover, location: "Dubai")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.cozyBackground)
    }

    private func layoverDuration(after flight: TripSegment?) -> String? {
        guard let flight = flight else { return nil }

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

        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(hours)h"
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
