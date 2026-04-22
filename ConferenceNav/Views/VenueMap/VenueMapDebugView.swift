#if DEBUG
import SwiftUI

/// DEBUG-only panel for pre-conference validation:
///   1. Pick which conference day My Day should treat as "today".
///   2. (Pin-crosshair toggle lives in VenueMapView's toolbar — not here.)
struct VenueMapDebugView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(DebugClock.self) private var clock

    var body: some View {
        @Bindable var clockBinding = clock

        Form {
            Section {
                Picker("Simulated date", selection: $clockBinding.simulatedDate) {
                    Text("Real today").tag(SimulatedConferenceDay?.none)
                    ForEach(SimulatedConferenceDay.allCases) { day in
                        Text(day.displayName).tag(SimulatedConferenceDay?.some(day))
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("My Day source")
            } footer: {
                Text("My Day overlay uses this date to decide which picks count as 'today'. Real today is used in production builds — this UI does not exist in release.")
            }

            Section {
                NavigationLink {
                    VenueMapView(focus: .browse(.floor3))
                } label: {
                    Label("Open Venue Map", systemImage: "map")
                }
            } footer: {
                Text("Use the scope icon in the venue map toolbar to toggle pin crosshairs and verify every catalogued room sits on its label.")
            }
        }
        .navigationTitle("Venue Map Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
