import SwiftUI
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject var tripData: TripDataService
    @State private var selectedTab = 0
    @State private var showDebugControls = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Where's Ben?
            NavigationStack {
                WhereIsBenView()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            headerView
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            debugButton
                        }
                    }
            }
            .tabItem {
                Label("Where's Ben?", systemImage: "mappin.and.ellipse")
            }
            .tag(0)

            // Tab 2: Flights
            NavigationStack {
                FlightsView()
                    .navigationTitle("Flights")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            headerView
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            debugButton
                        }
                    }
            }
            .tabItem {
                Label("Flights", systemImage: "airplane")
            }
            .tag(1)

            // Tab 3: Trip Info
            NavigationStack {
                TripInfoView()
                    .navigationTitle("Trip Info")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            headerView
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            debugButton
                        }
                    }
            }
            .tabItem {
                Label("Trip Info", systemImage: "list.bullet.clipboard")
            }
            .tag(2)

            // Tab 4: Kids
            KidsView()
                .tabItem {
                    Label("Kids", systemImage: "star.fill")
                }
                .tag(3)
        }
        .tint(.cozyAccent)
        .sheet(isPresented: $showDebugControls) {
            DebugTimeSheet()
        }
    }

    // MARK: - Debug Button

    private var debugButton: some View {
        Button {
            if tripData.isDebugMode {
                showDebugControls = true
            } else {
                tripData.isDebugMode = true
                showDebugControls = true
            }
        } label: {
            Image(systemName: tripData.isDebugMode ? "clock.badge.checkmark.fill" : "ladybug")
                .foregroundColor(tripData.isDebugMode ? .orange : .cozyTextSecondary)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            if tripData.isDebugMode {
                showDebugControls = true
            }
        } label: {
            HStack(spacing: 4) {
                if tripData.isDebugMode {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                Text(benTimeString)
                    .font(.cozyCaption)
                    .foregroundColor(tripData.isDebugMode ? .orange : .cozyTextSecondary)
            }
        }
        .disabled(!tripData.isDebugMode)
        .contextMenu {
            Button {
                tripData.isDebugMode.toggle()
                if tripData.isDebugMode {
                    showDebugControls = true
                } else {
                    tripData.resetDebugTime()
                }
            } label: {
                Label(
                    tripData.isDebugMode ? "Exit Debug Mode" : "Enter Debug Mode",
                    systemImage: tripData.isDebugMode ? "xmark.circle" : "ladybug"
                )
            }
        }
    }

    private var benTimeString: String {
        let now = tripData.effectiveNow
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM · HH:mm"

        // Determine Ben's current timezone
        let timezone: TimeZone
        if let coord = tripData.currentStatus.coordinate {
            if coord.latitude < 0 {
                timezone = TimeZone(identifier: "Australia/Sydney")!
            } else if coord.latitude > 20 && coord.latitude < 30 {
                timezone = TimeZone(identifier: "Asia/Dubai")!
            } else {
                timezone = TimeZone(identifier: "Europe/Prague")!
            }
        } else {
            timezone = TimeZone(identifier: "Australia/Sydney")!
        }

        formatter.timeZone = timezone
        let locationName = timezone.identifier.components(separatedBy: "/").last ?? ""
        return "\(locationName) · \(formatter.string(from: now))"
    }
}

// MARK: - Debug Time Sheet

struct DebugTimeSheet: View {
    @EnvironmentObject var tripData: TripDataService
    @Environment(\.dismiss) var dismiss

    // Trip dates for the picker
    private let tripStart = ISO8601DateFormatter().date(from: "2026-05-12T00:00:00Z")!
    private let tripEnd = ISO8601DateFormatter().date(from: "2026-05-18T23:59:59Z")!

    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Debug Mode")
                    .font(.cozyTitle)
                    .foregroundColor(.cozyText)

                Text("Scrub through the trip timeline to test different states")
                    .font(.cozyBody)
                    .foregroundColor(.cozyTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                DatePicker(
                    "Simulated Time",
                    selection: $selectedDate,
                    in: tripStart...tripEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { _, newValue in
                    tripData.setDebugTime(newValue)
                }

                // Quick jump buttons
                VStack(spacing: 12) {
                    Text("Quick Jump")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        QuickJumpButton(label: "Pre-trip", date: tripStart) {
                            selectedDate = tripStart
                        }
                        QuickJumpButton(label: "Flight 1", date: ISO8601DateFormatter().date(from: "2026-05-12T15:00:00Z")!) {
                            selectedDate = ISO8601DateFormatter().date(from: "2026-05-12T15:00:00Z")!
                        }
                        QuickJumpButton(label: "Dubai layover", date: ISO8601DateFormatter().date(from: "2026-05-13T02:00:00Z")!) {
                            selectedDate = ISO8601DateFormatter().date(from: "2026-05-13T02:00:00Z")!
                        }
                        QuickJumpButton(label: "Prague arrival", date: ISO8601DateFormatter().date(from: "2026-05-13T12:00:00Z")!) {
                            selectedDate = ISO8601DateFormatter().date(from: "2026-05-13T12:00:00Z")!
                        }
                        QuickJumpButton(label: "Conference", date: ISO8601DateFormatter().date(from: "2026-05-14T10:00:00Z")!) {
                            selectedDate = ISO8601DateFormatter().date(from: "2026-05-14T10:00:00Z")!
                        }
                        QuickJumpButton(label: "Coming home", date: ISO8601DateFormatter().date(from: "2026-05-17T10:00:00Z")!) {
                            selectedDate = ISO8601DateFormatter().date(from: "2026-05-17T10:00:00Z")!
                        }
                    }
                }
                .padding()

                // Test notification button
                Button {
                    NotificationService.shared.sendTestNotification()
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Send Test Notification")
                    }
                    .font(.cozyCaption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cozyAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset to Now") {
                        tripData.resetDebugTime()
                        tripData.isDebugMode = false
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                selectedDate = tripData.effectiveNow
            }
        }
    }
}

struct QuickJumpButton: View {
    let label: String
    let date: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.cozyCaption)
                .foregroundColor(.cozyAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cozyAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(TripDataService.shared)
}
