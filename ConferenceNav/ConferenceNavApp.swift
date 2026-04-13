import SwiftUI

@main
struct ConferenceNavApp: App {
    @State private var store = ConferenceStore()
    @State private var contactStore: ContactStore?
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
                            if let id = savedUserId {
                                contactStore = ContactStore(userId: id)
                            }
                        }
                    }
                }
                .environment(store)
                .environment(contactStore ?? ContactStore(userId: savedUserId ?? "default"))
                .onAppear {
                    if let id = savedUserId {
                        let user: UserProfile = id == "ron" ? .ron : .ben
                        store.switchUser(to: user)
                        if contactStore == nil {
                            contactStore = ContactStore(userId: id)
                        }
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
