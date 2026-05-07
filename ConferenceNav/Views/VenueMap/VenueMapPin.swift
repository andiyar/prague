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

    /// Diameter of the pin head in points. Total frame height is `size * 1.4`
    /// (the extra 40% is the tapered tip below the head).
    var size: CGFloat = 28

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    /// Tip extends 40% of the head diameter below the head.
    private var totalHeight: CGFloat { size * 1.4 }

    var body: some View {
        ZStack {
            // Pulse ring — always a Circle (radiates symmetrically from the head)
            if pulse {
                Circle()
                    .fill(CNColors.gold(for: colorScheme))
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .position(x: size / 2, y: size / 2)  // head centre
                    .onAppear {
                        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            pulseScale = 2.5
                            pulseOpacity = 0.0
                        }
                    }
            }

            // Solid teardrop pin (fills the full size × totalHeight frame)
            pinShape
                .fill(CNColors.gold(for: colorScheme))
                .overlay(pinShape.stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            // Optional number badge — centred in the rounded head
            if let label {
                Text(label)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .position(x: size / 2, y: size / 2)
            }
        }
        .frame(width: size, height: totalHeight)
        // Anchor: pin's tip at rect.maxY should sit at the position we're placed at.
        .offset(y: -totalHeight / 2)
    }

    private var pinShape: some Shape {
        TeardropShape()
    }
}

/// Round head on top, sharp tip at bottom-centre. The rect's full width is the
/// head diameter; the rect is ~1.4× taller than wide so the tip is prominent.
private struct TeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = w / 2
        let centre = CGPoint(x: w / 2, y: r)             // head centre, top portion
        let tip = CGPoint(x: w / 2, y: h)                // bottom-centre

        // Half-angle (from the centre-to-tip vertical) at which the tangent
        // lines from the tip touch the head circle. cos(α) = r / d.
        let d = max(h - r, r)
        let alpha = acos(r / d)
        let rightAngle = Angle(radians: .pi / 2 - alpha)
        let leftAngle  = Angle(radians: .pi / 2 + alpha)

        path.move(to: tip)
        // addArc draws an implicit line from current point to the start of the
        // arc, sweeps over the top of the head, then closeSubpath returns to tip.
        path.addArc(
            center: centre,
            radius: r,
            startAngle: rightAngle,
            endAngle: leftAngle,
            clockwise: true  // long way round — over the top of the head
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
