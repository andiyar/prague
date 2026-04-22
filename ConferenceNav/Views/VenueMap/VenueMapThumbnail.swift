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

            // Map preview cropped around the pin
            GeometryReader { geo in
                ZStack {
                    Image(room.floor.imageName)
                        .resizable()
                        .scaledToFill()
                        // Pan the image so the pin lands roughly in centre.
                        // 2.5× zoom, then offset so pinPosition centres in view.
                        .scaleEffect(2.5, anchor: UnitPoint(
                            x: room.pinPosition.x,
                            y: room.pinPosition.y
                        ))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    VenueMapPin(size: 32)
                }
                .frame(width: geo.size.width, height: geo.size.height)
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
}

#Preview {
    if let c2 = VenueMapCatalog.room(for: "C2") {
        VenueMapThumbnail(venue: c2.code)
            .padding()
    }
}
