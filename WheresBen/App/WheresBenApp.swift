import SwiftUI

@main
struct WheresBenApp: App {
    @StateObject private var tripData = TripDataService.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(tripData)
                .task {
                    await tripData.loadAllData()
                    tripData.startAutoRefresh()
                }
        }
    }
}
