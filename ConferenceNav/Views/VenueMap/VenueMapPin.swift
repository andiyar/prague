import SwiftUI

/// A teardrop map pin. Optional number badge for "My Day" mode.
/// Anchors at the bottom-centre of the teardrop, so position is the *tip*.
struct VenueMapPin: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Optional label displayed in the centre of the pin head.
    /// Use a number string ("1", "2", "1-2") for My Day mode.
    /// Pass `nil` for the plain single-room pin.
    var label: String? = nil

    /// When true, pulse rings expand outward continuously.
    var pulse: Bool = true

    /// Diameter of the pin head in points.
    var size: CGFloat = 28

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        ZStack {
            // Pulse ring (behind the pin, radiates outward)
            if pulse {
                pinShape
                    .fill(CNColors.gold(for: colorScheme))
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            pulseScale = 2.5
                            pulseOpacity = 0.0
                        }
                    }
            }

            // Solid pin
            pinShape
                .fill(CNColors.gold(for: colorScheme))
                .overlay(pinShape.stroke(.white, lineWidth: 2))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            // Optional number badge
            if let label {
                Text(label)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: -size * 0.08)  // visually centre in the rounded head
            }
        }
        // Anchor: pin's tip should be at the position we're placed at,
        // so shift the whole thing up by half its height.
        .offset(y: -size / 2)
    }

    /// Teardrop shape: a circle with a point at the bottom-left (rotated -45°).
    private var pinShape: some Shape {
        TeardropShape()
    }
}

/// Round on top, pointed at bottom-centre.
private struct TeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) / 2
        let centre = CGPoint(x: rect.midX, y: rect.midY)

        // Start at the bottom tip
        path.move(to: CGPoint(x: centre.x, y: rect.maxY))
        // Arc around the rounded head
        path.addArc(
            center: centre,
            radius: r,
            startAngle: .degrees(45),
            endAngle: .degrees(135),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 40) {
        VenueMapPin()
        VenueMapPin(label: "1")
        VenueMapPin(label: "1-2")
        VenueMapPin(pulse: false)
    }
    .padding(60)
    .background(Color.gray.opacity(0.2))
}
