import SwiftUI

@main
struct ConferenceNavApp: App {
    @State private var store = ConferenceStore()
    @AppStorage("conferenceNavUser") private var savedUserId: String?
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if savedUserId != nil {
                        MainTabView()
                    } else {
                        UserPickerView {
                            // onSelect — savedUserId set in UserPickerView
                        }
                    }
                }
                .environment(store)
                .onAppear {
                    if let id = savedUserId {
                        let user: UserProfile = id == "ron" ? .ron : .ben
                        store.switchUser(to: user)
                    }
                }
                .task {
                    if savedUserId != nil {
                        await store.syncPicks()
                    }
                }

                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
