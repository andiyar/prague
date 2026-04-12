import SwiftUI

struct ScheduleView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedDate = "2026-05-14"
    @State private var selectedTypes: Set<SessionType> = []
    @State private var selectedVenues: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    DayPicker(selectedDate: $selectedDate)
                        .padding(.horizontal, 16)

                    // Filter chips
                    VStack(spacing: 4) {
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

                    // Time slots
                    let timeSlots = store.timeSlotsForDate(selectedDate)
                    ForEach(timeSlots, id: \.self) { slot in
                        let allSessions = store.sessionsForDate(selectedDate)[slot] ?? []
                        let filtered = applyFilters(allSessions)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(slot)
                                    .font(CNFonts.time)
                                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                Text("· \(allSessions.count) parallel")
                                    .font(CNFonts.small)
                                    .foregroundStyle(CNColors.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            if filtered.isEmpty && !allSessions.isEmpty {
                                Text("No sessions match filters")
                                    .font(CNFonts.caption)
                                    .foregroundStyle(CNColors.textSecondary)
                                    .padding(.horizontal, 16)
                            } else {
                                ForEach(filtered) { session in
                                    NavigationLink(value: session.id) {
                                        SessionCardView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Data: \(store.lastUpdated)")
                        .font(CNFonts.small)
                        .foregroundStyle(CNColors.textSecondary)
                }
            }
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
        }
    }

    private func applyFilters(_ sessions: [Session]) -> [Session] {
        sessions.filter { session in
            (selectedTypes.isEmpty || selectedTypes.contains(session.type)) &&
            (selectedVenues.isEmpty || selectedVenues.contains(session.venue))
        }
    }
}
