import SwiftUI
import UserNotifications

@main
struct ConferenceNavApp: App {
    @State private var store = ConferenceStore()
    @State private var notificationService = NotificationService()
    @State private var contactStore: ContactStore?
    @State private var notesStore: NotesStore?
    @AppStorage("conferenceNavUser") private var savedUserId: String?
    @State private var showSplash = true

    init() {
        _store = State(initialValue: ConferenceStore())
        _notificationService = State(initialValue: NotificationService())

        UNUserNotificationCenter.current().delegate = _notificationService.wrappedValue
        _store.wrappedValue.notificationService = _notificationService.wrappedValue

        Self.sweepStaleExports()
    }

    /// Reaps export staging dirs and stale PDFs from previous sessions.
    /// PDFExportService and ExportView both write to /tmp/EAPC-{Export,PDF}-*
    /// and we can't reliably clean up after the share sheet dismisses,
    /// so we sweep on launch instead — safe because these are always
    /// session-scoped temp artefacts.
    private static func sweepStaleExports() {
        let tmp = FileManager.default.temporaryDirectory
        guard let entries = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) else {
            return
        }
        for url in entries {
            let name = url.lastPathComponent
            if name.hasPrefix("EAPC-Export-") || name.hasPrefix("EAPC-PDF-") || name.hasPrefix("EAPC-2026-") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

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
                                notesStore = NotesStore(userId: id)
                            }
                        }
                    }
                }
                .environment(store)
                .environment(contactStore ?? ContactStore(userId: savedUserId ?? "default"))
                .environment(notesStore ?? NotesStore(userId: savedUserId ?? "default"))
                .environment(notificationService)
                .environment(DebugClock.shared)
                .onAppear {
                    if let id = savedUserId {
                        let user: UserProfile = id == "ron" ? .ron : .ben
                        store.switchUser(to: user)
                        if contactStore == nil {
                            contactStore = ContactStore(userId: id)
                        }
                        if notesStore == nil {
                            notesStore = NotesStore(userId: id)
                        }
                    }
                }
                .task {
                    if savedUserId != nil {
                        await store.syncPicks()
                        await notificationService.requestPermission()
                        // After permission resolves, reschedule using the
                        // picks already loaded from disk during store.init —
                        // those didn't trigger a schedule because the service
                        // wasn't attached / authorized at the time.
                        store.rescheduleNotifications()
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
