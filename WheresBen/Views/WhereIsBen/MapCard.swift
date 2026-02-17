import SwiftUI
import MapKit

struct MapCard: View {
    @EnvironmentObject var tripData: TripDataService
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(position: $position) {
                // Flight paths
                if showFlightPaths {
                    // Sydney to Dubai
                    MapPolyline(coordinates: flightPath(from: Airports.sydney, to: Airports.dubai))
                        .stroke(.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

                    // Dubai to Prague
                    MapPolyline(coordinates: flightPath(from: Airports.dubai, to: Airports.prague))
                        .stroke(.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }

                // Airport markers
                ForEach(Airports.all, id: \.name) { airport in
                    Annotation(airport.name, coordinate: airport.coordinate) {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 10, height: 10)
                    }
                }

                // Ben's current position
                if let coordinate = tripData.currentStatus.coordinate {
                    Annotation("Ben", coordinate: coordinate) {
                        if tripData.currentStatus.isFlying {
                            // Plane marker when flying
                            Text("✈️")
                                .font(.system(size: 28))
                                .rotationEffect(.degrees(planeRotation))
                        } else {
                            // Pin marker when stationary
                            VStack(spacing: 0) {
                                Text("📍")
                                    .font(.system(size: 32))
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear {
                updateMapPosition()
            }
            .onChange(of: tripData.currentStatus.coordinate?.latitude) { _, _ in
                updateMapPosition()
            }
        }
        .cozyCard()
    }

    private var showFlightPaths: Bool {
        // Show paths during the trip
        true
    }

    private var planeRotation: Double {
        guard let from = tripData.currentStatus.flightFrom,
              let to = tripData.currentStatus.flightTo,
              let fromAirport = Airports.all.first(where: { $0.code == from }),
              let toAirport = Airports.all.first(where: { $0.code == to }) else {
            return 0
        }

        return bearing(from: fromAirport.coordinate, to: toAirport.coordinate) - 90
    }

    private func updateMapPosition() {
        if let coordinate = tripData.currentStatus.coordinate {
            let span = tripData.currentStatus.isFlying
                ? MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                : MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)

            withAnimation {
                position = .region(MKCoordinateRegion(center: coordinate, span: span))
            }
        }
    }

    private func flightPath(from: Airport, to: Airport) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []

        let midLat = (from.coordinate.latitude + to.coordinate.latitude) / 2
        let midLng = (from.coordinate.longitude + to.coordinate.longitude) / 2

        let latDiff = to.coordinate.latitude - from.coordinate.latitude
        let lngDiff = to.coordinate.longitude - from.coordinate.longitude
        let offset = sqrt(latDiff * latDiff + lngDiff * lngDiff) * 0.2

        let controlLat = midLat + offset
        let controlLng = midLng

        for i in 0...20 {
            let t = Double(i) / 20.0
            let lat = (1 - t) * (1 - t) * from.coordinate.latitude +
                      2 * (1 - t) * t * controlLat +
                      t * t * to.coordinate.latitude
            let lng = (1 - t) * (1 - t) * from.coordinate.longitude +
                      2 * (1 - t) * t * controlLng +
                      t * t * to.coordinate.longitude
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }

        return points
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLng = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }
}

// MARK: - Airport Data

struct Airport {
    let name: String
    let code: String
    let coordinate: CLLocationCoordinate2D
}

enum Airports {
    static let sydney = Airport(
        name: "Sydney",
        code: "SYD",
        coordinate: CLLocationCoordinate2D(latitude: -33.9461, longitude: 151.1772)
    )

    static let dubai = Airport(
        name: "Dubai",
        code: "DXB",
        coordinate: CLLocationCoordinate2D(latitude: 25.2532, longitude: 55.3657)
    )

    static let prague = Airport(
        name: "Prague",
        code: "PRG",
        coordinate: CLLocationCoordinate2D(latitude: 50.1008, longitude: 14.2600)
    )

    static let all = [sydney, dubai, prague]
}

#Preview {
    ZStack {
        Color.cozyBackground.ignoresSafeArea()
        MapCard()
            .padding()
    }
    .environmentObject(TripDataService.shared)
}
