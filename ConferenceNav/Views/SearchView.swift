import SwiftUI

struct SearchView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var query = ""
    @State private var selectedDates: Set<String> = []
    @State private var selectedTypes: Set<SessionType> = []
    @State private var selectedVenues: Set<String> = []

    var results: [Session] {
        var sessions: [Session]
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            sessions = store.browseableSessions
        } else {
            sessions = store.search(query)
        }

        sessions = sessions.filter { session in
            (selectedDates.isEmpty || selectedDates.contains(session.date)) &&
            (selectedTypes.isEmpty || selectedTypes.contains(session.type)) &&
            (selectedVenues.isEmpty || selectedVenues.contains(session.venue))
        }

        return sessions.sorted { ($0.date, $0.startsAt) < ($1.date, $1.startsAt) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CNColors.textSecondary)
                    TextField("Search sessions, speakers, topics...", text: $query)
                        .font(CNFonts.body)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(CNColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(CNColors.surfaceSecondary(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Filter chips
                VStack(spacing: 4) {
                    FilterChips(
                        label: "Day",
                        options: store.dates,
                        selected: $selectedDates,
                        title: { date in
                            switch date {
                            case "2026-05-14": return "Thu"
                            case "2026-05-15": return "Fri"
                            case "2026-05-16": return "Sat"
                            default: return date
                            }
                        }
                    )
                    FilterChips(
                        label: "Type",
                        options: SessionType.filterableTypes,
                        selected: $selectedTypes,
                        title: \.rawValue
                    )
                    FilterChips(
                        label: "Room",
                        options: store.allVenues,
                        selected: $selectedVenues,
                        title: { $0 }
                    )
                }
                .padding(.vertical, 4)

                // Results
                if query.isEmpty && selectedDates.isEmpty && selectedTypes.isEmpty && selectedVenues.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(CNColors.textSecondary.opacity(0.5))
                        Text("Search sessions, speakers, topics...")
                            .font(CNFonts.body)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No matches")
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                        Text("Try different keywords or adjust filters")
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { session in
                                NavigationLink(value: SessionNav(session.id, query: query)) {
                                    SessionCardView(session: session, showTime: true)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .cnPadMaxWidth(CNLayout.MaxWidth.tabContent)
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Search")
            .navigationDestination(for: SessionNav.self) { nav in
                if let session = store.sessions.first(where: { $0.id == nav.sessionId }) {
                    SessionDetailView(session: session, searchQuery: nav.searchQuery)
                }
            }
        }
    }
}
