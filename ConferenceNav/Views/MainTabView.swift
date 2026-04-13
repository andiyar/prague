import SwiftUI

struct MainTabView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            MyPicksView()
                .tabItem {
                    Label("My Picks", systemImage: "star.fill")
                }

            ExtrasView()
                .tabItem {
                    Label("Extras", systemImage: "ellipsis.circle.fill")
                }
        }
        .tint(CNColors.navy(for: colorScheme))
    }
}
