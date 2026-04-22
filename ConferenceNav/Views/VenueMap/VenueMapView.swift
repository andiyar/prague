import SwiftUI

/// What the map should highlight when it first opens.
enum VenueMapFocus: Equatable {
    /// Centre on a specific room, place a pulsing pin.
    case specificRoom(VenueRoom)
    /// Show a floor with no pin (general browsing from Extras).
    case browse(VenueFloor)
}

/// Full-screen zoomable floor plan.
struct VenueMapView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let focus: VenueMapFocus

    @State private var currentFloor: VenueFloor
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    #if DEBUG
    @State private var showCrosshairs: Bool = false
    #endif

    init(focus: VenueMapFocus) {
        self.focus = focus
        switch focus {
        case .specificRoom(let room):
            _currentFloor = State(initialValue: room.floor)
        case .browse(let floor):
            _currentFloor = State(initialValue: floor)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapArea
                floorSwitcher
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle(currentFloor.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCrosshairs.toggle()
                    } label: {
                        Image(systemName: showCrosshairs ? "scope" : "scope")
                            .foregroundStyle(showCrosshairs ? CNColors.red(for: colorScheme) : CNColors.textSecondary)
                    }
                }
                #endif
            }
        }
    }

    // MARK: - Map area

    private var mapArea: some View {
        GeometryReader { geo in
            ZStack {
                Image(currentFloor.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(pinOverlay(in: geo.size))
                    #if DEBUG
                    .overlay(crosshairOverlay(in: geo.size))
                    #endif
                    .scaleEffect(zoom)
                    .offset(offset)
                    .gesture(zoomGesture)
                    .simultaneousGesture(panGesture)
                    .onTapGesture(count: 2) { resetTransform() }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    /// Pin shown for the focused room (if any).
    @ViewBuilder
    private func pinOverlay(in size: CGSize) -> some View {
        if case .specificRoom(let room) = focus, room.floor == currentFloor {
            // Image is scaledToFit inside `size`, so compute the actual displayed image rect.
            let rect = displayedImageRect(in: size)
            VenueMapPin()
                .position(
                    x: rect.minX + room.pinPosition.x * rect.width,
                    y: rect.minY + room.pinPosition.y * rect.height
                )
        }
    }

    #if DEBUG
    /// Crosshair + room code at every catalog pin on this floor.
    @ViewBuilder
    private func crosshairOverlay(in size: CGSize) -> some View {
        if showCrosshairs {
            let rect = displayedImageRect(in: size)
            ForEach(VenueMapCatalog.rooms(on: currentFloor)) { room in
                ZStack {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                    Text(room.code)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Capsule())
                        .offset(y: 14)
                }
                .position(
                    x: rect.minX + room.pinPosition.x * rect.width,
                    y: rect.minY + room.pinPosition.y * rect.height
                )
            }
        }
    }
    #endif

    /// scaledToFit centres the image inside its frame; this returns the actual
    /// rendered rectangle so we can position pins relative to the image, not
    /// the surrounding frame.
    private func displayedImageRect(in containerSize: CGSize) -> CGRect {
        // Floor plans: 1050 wide × ~950 tall (varies). Aspect ratio depends on the floor;
        // we use the runtime UIImage to be exact.
        guard let ui = UIImage(named: currentFloor.imageName) else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let imgSize = ui.size
        let imgAspect = imgSize.width / imgSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imgAspect > containerAspect {
            // Image is wider — letterbox top/bottom
            let displayedWidth = containerSize.width
            let displayedHeight = displayedWidth / imgAspect
            let yOffset = (containerSize.height - displayedHeight) / 2
            return CGRect(x: 0, y: yOffset, width: displayedWidth, height: displayedHeight)
        } else {
            // Image is taller — pillarbox left/right
            let displayedHeight = containerSize.height
            let displayedWidth = displayedHeight * imgAspect
            let xOffset = (containerSize.width - displayedWidth) / 2
            return CGRect(x: xOffset, y: 0, width: displayedWidth, height: displayedHeight)
        }
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = max(1.0, min(5.0, lastZoom * value))
            }
            .onEnded { _ in
                lastZoom = zoom
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetTransform() {
        withAnimation(.spring(response: 0.4)) {
            zoom = 1.0
            lastZoom = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: - Floor switcher

    private var floorSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(VenueFloor.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { floor in
                Button {
                    selectFloor(floor)
                } label: {
                    Text(floor.shortLabel)
                        .font(CNFonts.headline)
                        .foregroundStyle(
                            floor == currentFloor
                                ? CNColors.background(for: colorScheme)
                                : CNColors.textPrimary(for: colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            floor == currentFloor
                                ? CNColors.navy(for: colorScheme)
                                : CNColors.surface(for: colorScheme)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(CNColors.surface(for: colorScheme))
        .overlay(Divider(), alignment: .top)
    }

    private func selectFloor(_ floor: VenueFloor) {
        currentFloor = floor
        resetTransform()
    }
}

#Preview("Specific room") {
    if let c2 = VenueMapCatalog.room(for: "C2") {
        VenueMapView(focus: .specificRoom(c2))
    }
}

#Preview("Browse mode") {
    VenueMapView(focus: .browse(.floor3))
}
