import SwiftUI

struct MainTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ConferenceStore.self) var store
    @Environment(NotificationService.self) var notificationService

    @State private var selectedTab = 0
    @State private var navigateToSessionId: Int?

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView(navigateToSessionId: $navigateToSessionId)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            MyPicksView()
                .tabItem {
                    Label("My Picks", systemImage: "star.fill")
                }
                .tag(2)

            ExtrasView()
                .tabItem {
                    Label("Extras", systemImage: "ellipsis.circle.fill")
                }
                .tag(3)
        }
        .tint(CNColors.navy(for: colorScheme))
        .onChange(of: notificationService.selectedSessionId) { _, sessionId in
            guard let sessionId else { return }
            selectedTab = 0
            navigateToSessionId = sessionId
            notificationService.selectedSessionId = nil
        }
    }
}
