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
    @Environment(ConferenceStore.self) private var store
    @Environment(DebugClock.self) private var clock

    let focus: VenueMapFocus

    @State private var currentFloor: VenueFloor
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var showMyDay: Bool = false

    #if DEBUG
    @State private var showCrosshairs: Bool = false
    #endif

    private var myDayPins: [MyDayPin] {
        MyDayOverlay.pins(
            for: clock.currentDay,
            sessions: store.sessions,
            picks: store.myPicks
        )
    }

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMyDay.toggle()
                    } label: {
                        Image(systemName: showMyDay ? "calendar.badge.checkmark" : "calendar")
                            .foregroundStyle(showMyDay ? CNColors.gold(for: colorScheme) : CNColors.textSecondary)
                    }
                    .accessibilityLabel(showMyDay ? "Hide My Day" : "Show My Day")
                }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCrosshairs.toggle()
                    } label: {
                        Image(systemName: "scope")
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
                    .overlay(myDayOverlay(in: geo.size))
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
            .onAppear { containerSize = geo.size }
            .onChange(of: geo.size) { _, new in containerSize = new }
        }
    }

    /// Returns `offset` clamped so the displayed image (at the current zoom) cannot
    /// be dragged past the container's edges.
    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        let imageRect = displayedImageRect(in: containerSize)
        let imageWidth = imageRect.width * zoom
        let imageHeight = imageRect.height * zoom
        let maxOffsetX = max(0, (imageWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (imageHeight - containerSize.height) / 2)
        return CGSize(
            width: min(maxOffsetX, max(-maxOffsetX, proposed.width)),
            height: min(maxOffsetY, max(-maxOffsetY, proposed.height))
        )
    }

    /// Pin shown for the focused room (if any). Hidden while the My Day
    /// overlay is active so the two pin sets don't overlap.
    @ViewBuilder
    private func pinOverlay(in size: CGSize) -> some View {
        if !showMyDay,
           case .specificRoom(let room) = focus,
           room.floor == currentFloor
        {
            // Image is scaledToFit inside `size`, so compute the actual displayed image rect.
            let rect = displayedImageRect(in: size)
            VenueMapPin()
                .position(
                    x: rect.minX + room.pinPosition.x * rect.width,
                    y: rect.minY + room.pinPosition.y * rect.height
                )
        }
    }

    /// Numbered overlay of all of today's picks.
    @ViewBuilder
    private func myDayOverlay(in size: CGSize) -> some View {
        if showMyDay {
            let rect = displayedImageRect(in: size)
            MyDayOverlayView(
                pins: myDayPins,
                floor: currentFloor,
                displayedImageRect: rect
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
                // Re-clamp offset against the new zoom so we don't end up out of bounds
                // when zooming out from a panned position.
                offset = clampedOffset(offset)
            }
            .onEnded { _ in
                lastZoom = zoom
                lastOffset = offset
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed)
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
            .environment(ConferenceStore())
            .environment(DebugClock.shared)
    }
}

#Preview("Browse mode") {
    VenueMapView(focus: .browse(.floor3))
        .environment(ConferenceStore())
        .environment(DebugClock.shared)
}
