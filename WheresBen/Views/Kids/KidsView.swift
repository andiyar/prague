import SwiftUI
import MapKit

struct KidsView: View {
    @EnvironmentObject var tripData: TripDataService
    @State private var emojiScale: CGFloat = 1.0
    @State private var showSparkles = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Sky background
            KidsSkyBackground()

            // Floating clouds
            FloatingCloud(size: 100, duration: 25, delay: 0)
                .position(x: 50, y: 80)
            FloatingCloud(size: 80, duration: 35, delay: 10)
                .position(x: 150, y: 150)
            FloatingCloud(size: 120, duration: 40, delay: 20)
                .position(x: 300, y: 60)

            // Sun
            Circle()
                .fill(Color.kidsSun)
                .frame(width: 80, height: 80)
                .shadow(color: .kidsSun.opacity(0.5), radius: 30)
                .position(x: UIScreen.main.bounds.width - 60, y: 80)

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Big status emoji
                statusSection

                // Map
                mapSection

                // Sleeps countdown
                sleepsSection

                Spacer()
            }
            .padding()

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(tripData.currentStatus.emoji)
                .font(.kidsGiant)
                .scaleEffect(emojiScale)
                .onTapGesture {
                    withAnimation(.bouncy) {
                        emojiScale = 1.3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.bouncy) {
                            emojiScale = 1.0
                        }
                    }

                    // Special animation for plane
                    if tripData.currentStatus.isFlying {
                        // Could add a loop animation here
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

            Text(tripData.currentStatus.kidsText)
                .font(.kidsTitle)
                .foregroundColor(.cozyText)
                .multilineTextAlignment(.center)
                .shadow(color: .white, radius: 2)
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        ZStack {
            // Map
            Map {
                // Flight paths
                MapPolyline(coordinates: flightPath(from: Airports.sydney, to: Airports.dubai))
                    .stroke(.purple.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [8, 8]))

                MapPolyline(coordinates: flightPath(from: Airports.dubai, to: Airports.prague))
                    .stroke(.purple.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [8, 8]))

                // Daddy's position
                if let coord = tripData.currentStatus.coordinate {
                    Annotation("", coordinate: coord) {
                        if tripData.currentStatus.isFlying {
                            Text("✈️")
                                .font(.system(size: 36))
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        } else {
                            VStack(spacing: 0) {
                                Text("👨")
                                    .font(.system(size: 32))
                                Circle()
                                    .fill(Color.kidsPurple)
                                    .frame(width: 12, height: 12)
                                    .offset(y: -4)
                            }
                        }
                    }
                }
            }
            .mapStyle(.imagery)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white, lineWidth: 4)
            )
            .shadow(color: .kidsPurple.opacity(0.3), radius: 20)
        }
    }

    // MARK: - Sleeps Section

    private var sleepsSection: some View {
        VStack(spacing: 8) {
            Text("\(tripData.sleepsUntilHome)")
                .font(.kidsLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.kidsPurple, .kidsPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .onTapGesture {
                    withAnimation(.bouncy) {
                        showSparkles = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showSparkles = false
                    }
                }
                .overlay {
                    if showSparkles {
                        SparklesView()
                    }
                }

            HStack(spacing: 8) {
                Text("🌙")
                    .font(.title)
                Text(tripData.sleepsUntilHome == 1 ? "sleep until Daddy's home!" : "sleeps until Daddy's home!")
                    .font(.kidsBody)
                    .foregroundColor(.cozyText)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .kidsPurple.opacity(0.2), radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.kidsPurple, .kidsPink, .kidsSun],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
    }

    // MARK: - Flight Path Helper

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
}

// MARK: - Sparkles View

struct SparklesView: View {
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Image(systemName: "sparkle")
                    .foregroundColor([.kidsSun, .kidsPurple, .kidsPink][i % 3])
                    .font(.title)
                    .offset(
                        x: CGFloat.random(in: -50...50),
                        y: CGFloat.random(in: -50...50)
                    )
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<50) { i in
                ConfettiPiece(
                    color: [.kidsPurple, .kidsPink, .kidsSun, .cozySage, .cozyAccent][i % 5],
                    size: CGFloat.random(in: 8...16)
                )
                .position(
                    x: CGFloat.random(in: 0...geo.size.width),
                    y: CGFloat.random(in: 0...geo.size.height)
                )
            }
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat

    @State private var rotation: Double = 0
    @State private var yOffset: CGFloat = -100

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size, height: size * 1.5)
            .rotationEffect(.degrees(rotation))
            .offset(y: yOffset)
            .onAppear {
                withAnimation(.linear(duration: Double.random(in: 2...4)).repeatForever(autoreverses: false)) {
                    rotation = 360
                    yOffset = UIScreen.main.bounds.height + 100
                }
            }
    }
}

#Preview {
    KidsView()
        .environmentObject(TripDataService.shared)
}
