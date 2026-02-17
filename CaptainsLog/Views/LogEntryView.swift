import SwiftUI
import CoreLocation

struct LogEntryView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var isSending = false
    @State private var showConfirmation = false
    @State private var showCustomMessage = false
    @State private var customMessage = ""
    @State private var lastSentStatus: QuickStatus?
    @State private var recentUpdates: [RecentUpdate] = []
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.cozyBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Location header
                    locationHeader

                    // Quick status grid
                    QuickStatusGrid(
                        onStatusSelected: { status in
                            sendStatus(status)
                        },
                        onCustomSelected: {
                            showCustomMessage = true
                        },
                        isEnabled: !isSending
                    )

                    Spacer()

                    // Recent updates toggle
                    if !recentUpdates.isEmpty {
                        recentUpdatesSection
                    }
                }
                .padding()

                // Confirmation overlay
                if showConfirmation {
                    confirmationOverlay
                }
            }
            .navigationTitle("Captain's Log")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCustomMessage) {
                customMessageSheet
            }
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }

    // MARK: - Location Header

    private var locationHeader: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.cozyAccent)

            if let location = locationManager.currentPlacemark {
                Text(location)
                    .font(.cozyBody)
                    .foregroundColor(.cozyText)
            } else if locationManager.isLoading {
                Text("Finding location...")
                    .font(.cozyBody)
                    .foregroundColor(.cozyTextSecondary)
            } else {
                Text("Location unavailable")
                    .font(.cozyBody)
                    .foregroundColor(.cozyTextSecondary)
            }

            Spacer()

            Text(currentTimeString)
                .font(.cozyCaption)
                .foregroundColor(.cozyTextSecondary)
        }
        .padding()
        .background(Color.cozyCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Recent Updates

    private var recentUpdatesSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.gentleBounce) {
                    showHistory.toggle()
                }
            } label: {
                HStack {
                    Text("Recent Updates")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                    Spacer()
                    Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.cozyTextSecondary)
                }
            }

            if showHistory {
                VStack(spacing: 8) {
                    ForEach(recentUpdates.prefix(5)) { update in
                        HStack {
                            Text(update.emoji)
                            Text(update.text)
                                .font(.cozyCaption)
                                .foregroundColor(.cozyText)
                            Spacer()
                            Text(update.timeAgo)
                                .font(.cozyCaption)
                                .foregroundColor(.cozyTextSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.cozyCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: 16) {
            Text("✓")
                .font(.system(size: 60))
                .foregroundColor(.cozySage)

            Text("Sent!")
                .font(.cozyTitle)
                .foregroundColor(.cozyText)

            if let status = lastSentStatus {
                Text("\(status.emoji) \(status.label)")
                    .font(.cozyBody)
                    .foregroundColor(.cozyTextSecondary)
            }
        }
        .padding(40)
        .background(Color.cozyCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Custom Message Sheet

    private var customMessageSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Add a note for the family...", text: $customMessage, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Button {
                    sendCustomMessage()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    .font(.cozyHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cozyAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(customMessage.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Custom Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomMessage = false
                        customMessage = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func sendStatus(_ status: QuickStatus) {
        guard !isSending else { return }

        isSending = true
        lastSentStatus = status

        Task {
            do {
                try await SupabaseClient.shared.postStatusOverride(
                    emoji: status.emoji,
                    statusText: status.statusText,
                    kidsText: status.kidsText,
                    note: nil,
                    latitude: locationManager.coordinate?.latitude,
                    longitude: locationManager.coordinate?.longitude
                )

                // Add to recent updates
                let update = RecentUpdate(
                    emoji: status.emoji,
                    text: status.label,
                    sentAt: Date()
                )
                recentUpdates.insert(update, at: 0)

                // Show confirmation
                withAnimation(.bouncy) {
                    showConfirmation = true
                }

                // Hide after delay
                try await Task.sleep(nanoseconds: 1_500_000_000)

                withAnimation(.bouncy) {
                    showConfirmation = false
                }

            } catch {
                print("Error sending status: \(error)")
            }

            isSending = false
        }
    }

    private func sendCustomMessage() {
        guard !isSending else { return }

        let message = customMessage.trimmingCharacters(in: .whitespaces)
        guard !message.isEmpty else { return }

        isSending = true

        Task {
            do {
                try await SupabaseClient.shared.postStatusOverride(
                    emoji: "💬",
                    statusText: message,
                    kidsText: "Daddy sent a message!",
                    note: message,
                    latitude: locationManager.coordinate?.latitude,
                    longitude: locationManager.coordinate?.longitude
                )

                // Add to recent updates
                let update = RecentUpdate(
                    emoji: "💬",
                    text: message,
                    sentAt: Date()
                )
                recentUpdates.insert(update, at: 0)

                // Reset and close
                customMessage = ""
                showCustomMessage = false

                // Show confirmation
                lastSentStatus = QuickStatus(
                    emoji: "💬",
                    label: "Custom",
                    statusText: message,
                    kidsText: "Daddy sent a message!"
                )

                withAnimation(.bouncy) {
                    showConfirmation = true
                }

                try await Task.sleep(nanoseconds: 1_500_000_000)

                withAnimation(.bouncy) {
                    showConfirmation = false
                }

            } catch {
                print("Error sending custom message: \(error)")
            }

            isSending = false
        }
    }
}

// MARK: - Recent Update Model

struct RecentUpdate: Identifiable {
    let id = UUID()
    let emoji: String
    let text: String
    let sentAt: Date

    var timeAgo: String {
        let diff = Int(Date().timeIntervalSince(sentAt) / 60)
        if diff < 1 { return "Just now" }
        if diff < 60 { return "\(diff)m ago" }
        return "\(diff / 60)h ago"
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var coordinate: CLLocationCoordinate2D?
    @Published var currentPlacemark: String?
    @Published var isLoading = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isLoading = true
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate

        // Reverse geocode
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let placemark = placemarks?.first {
                    let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
                        .compactMap { $0 }
                    self?.currentPlacemark = parts.joined(separator: ", ")
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        print("Location error: \(error)")
    }
}

#Preview {
    LogEntryView()
}
