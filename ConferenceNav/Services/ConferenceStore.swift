import SwiftUI

@Observable
class ConferenceStore {
    // MARK: - Data
    private(set) var sessions: [Session] = []
    var currentUser: UserProfile = .ben
    let lastUpdated = "12 April 2026"

    // MARK: - Picks
    var myPicks: Set<Int> = [] {
        didSet { savePicksLocally() }
    }
    var matePicks: Set<Int> = []

    // MARK: - Search
    var searchIndex = SearchIndex()

    // MARK: - Sync
    private let syncService = PicksSyncService()

    // MARK: - Init

    init() {
        loadSessions()
        loadPicksLocally()
        searchIndex.build(from: sessions)
    }

    // MARK: - Session Loading

    private func loadSessions() {
        guard let url = Bundle.main.url(forResource: "programme", withExtension: "json") else {
            print("ERROR: programme.json not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            sessions = try decoder.decode([Session].self, from: data)
            print("Loaded \(sessions.count) sessions")
        } catch {
            print("Failed to decode programme.json: \(error)")
        }
    }

    // MARK: - Browseable Sessions

    var browseableSessions: [Session] {
        sessions.filter(\.isBrowseable)
    }

    var dates: [String] {
        ["2026-05-14", "2026-05-15", "2026-05-16"]
    }

    func sessionsForDate(_ date: String) -> [String: [Session]] {
        let daySessions = browseableSessions.filter { $0.date == date }
        return Dictionary(grouping: daySessions) { $0.timeSlot }
    }

    func timeSlotsForDate(_ date: String) -> [String] {
        let groups = sessionsForDate(date)
        return groups.keys.sorted { a, b in
            let aStart = a.components(separatedBy: " - ").first ?? a
            let bStart = b.components(separatedBy: " - ").first ?? b
            return aStart < bStart
        }
    }

    // MARK: - All unique venues (for filter chips)

    var allVenues: [String] {
        let venues = Set(browseableSessions.map(\.venue))
        return venues.sorted()
    }

    // MARK: - Pick Management

    func isPicked(_ sessionId: Int) -> Bool {
        myPicks.contains(sessionId)
    }

    func isMatePicked(_ sessionId: Int) -> Bool {
        matePicks.contains(sessionId)
    }

    func togglePick(_ sessionId: Int) {
        let removing = myPicks.contains(sessionId)
        if removing {
            myPicks.remove(sessionId)
        } else {
            myPicks.insert(sessionId)
        }
        Task {
            do {
                if removing {
                    try await syncService.removePick(userId: currentUser.id, sessionId: sessionId)
                } else {
                    try await syncService.addPick(userId: currentUser.id, sessionId: sessionId)
                }
            } catch {
                print("Failed to sync pick: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - My Picked Sessions

    var myPickedSessions: [Session] {
        browseableSessions
            .filter { myPicks.contains($0.id) }
            .sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    var matePickedSessions: [Session] {
        browseableSessions
            .filter { matePicks.contains($0.id) }
            .sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    var bothPickedSessions: [Session] {
        browseableSessions
            .filter { myPicks.contains($0.id) && matePicks.contains($0.id) }
            .sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    // MARK: - Conflict Detection

    func conflictingSession(for session: Session) -> Session? {
        let picked = myPickedSessions.filter { $0.date == session.date && $0.id != session.id }
        return picked.first { session.conflicts(with: $0) }
    }

    func hasConflict(_ session: Session) -> Bool {
        conflictingSession(for: session) != nil
    }

    // MARK: - Pick Summary

    func pickCount(for date: String) -> Int {
        myPickedSessions.filter { $0.date == date }.count
    }

    // MARK: - Search

    func search(_ query: String) -> [Session] {
        let ids = searchIndex.search(query)
        let idSet = Set(ids)
        return browseableSessions.filter { idSet.contains($0.id) }
    }

    // MARK: - Supabase Sync

    func syncPicks() async {
        do {
            let myRemotePicks = try await syncService.fetchPicks(userId: currentUser.id)
            let mateRemotePicks = try await syncService.fetchPicks(userId: currentUser.mate.id)

            await MainActor.run {
                let merged = myPicks.union(myRemotePicks)
                if merged != myPicks {
                    myPicks = merged
                }
                matePicks = mateRemotePicks
            }

            // Push any local-only picks to remote
            let localOnly = myPicks.subtracting(myRemotePicks)
            for sessionId in localOnly {
                try await syncService.addPick(userId: currentUser.id, sessionId: sessionId)
            }
        } catch {
            print("Pick sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Local Persistence

    private var picksKey: String { "conferencePicks_\(currentUser.id)" }

    private func savePicksLocally() {
        UserDefaults.standard.set(Array(myPicks), forKey: picksKey)
    }

    private func loadPicksLocally() {
        let array = UserDefaults.standard.array(forKey: picksKey) as? [Int] ?? []
        myPicks = Set(array)
    }

    func switchUser(to user: UserProfile) {
        savePicksLocally()
        currentUser = user
        loadPicksLocally()
    }
}
