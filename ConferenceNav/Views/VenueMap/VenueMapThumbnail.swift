import SwiftUI

/// Compact card embedded in `SessionDetailView`. Tapping opens `VenueMapView`
/// focused on this session's room. Renders nothing for unknown venues.
struct VenueMapThumbnail: View {
    @Environment(\.colorScheme) private var colorScheme

    let venue: String

    @State private var showingMap = false

    var body: some View {
        if let room = VenueMapCatalog.room(for: venue) {
            Button {
                showingMap = true
            } label: {
                cardBody(for: room)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingMap) {
                VenueMapView(focus: .specificRoom(room))
            }
        }
        // else: render nothing — graceful fallback for unknown venues
    }

    @ViewBuilder
    private func cardBody(for room: VenueRoom) -> some View {
        VStack(spacing: 0) {
            // Header strip
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(room.displayName) · \(room.floor.displayName)")
                    .font(CNFonts.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        CNColors.navy(for: colorScheme),
                        CNColors.navy(for: colorScheme).opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Map preview cropped to centre the pin
            GeometryReader { geo in
                let size = geo.size
                let imageRect = displayedImageRect(for: room.floor, in: size)
                let pinPreScale = CGPoint(
                    x: imageRect.minX + room.pinPosition.x * imageRect.width,
                    y: imageRect.minY + room.pinPosition.y * imageRect.height
                )
                let zoom: CGFloat = 2.5
                let computedOffset = CGSize(
                    width: zoom * (size.width / 2 - pinPreScale.x),
                    height: zoom * (size.height / 2 - pinPreScale.y)
                )

                ZStack {
                    Image(room.floor.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(zoom)
                        .offset(computedOffset)

                    VenueMapPin(size: 32)
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
            .frame(height: 140)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CNColors.surfaceSecondary(for: colorScheme), lineWidth: 1)
        )
    }

    /// Computes the actual rendered image rect inside a scaledToFit frame.
    /// Matches the same logic in `VenueMapView.displayedImageRect(in:)`.
    private func displayedImageRect(for floor: VenueFloor, in containerSize: CGSize) -> CGRect {
        guard let ui = UIImage(named: floor.imageName) else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let imgSize = ui.size
        let imgAspect = imgSize.width / imgSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imgAspect > containerAspect {
            let displayedWidth = containerSize.width
            let displayedHeight = displayedWidth / imgAspect
            let yOffset = (containerSize.height - displayedHeight) / 2
            return CGRect(x: 0, y: yOffset, width: displayedWidth, height: displayedHeight)
        } else {
            let displayedHeight = containerSize.height
            let displayedWidth = displayedHeight * imgAspect
            let xOffset = (containerSize.width - displayedWidth) / 2
            return CGRect(x: xOffset, y: 0, width: displayedWidth, height: displayedHeight)
        }
    }
}

#Preview {
    if let c2 = VenueMapCatalog.room(for: "C2") {
        VenueMapThumbnail(venue: c2.code)
            .padding()
    }
}
