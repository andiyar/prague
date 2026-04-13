import SwiftUI

struct MyPicksView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    enum PicksFilter: String, CaseIterable {
        case mine = "Mine"
        case ben = "Ben"
        case ron = "Ron"
        case both = "Both"
    }

    @State private var filter: PicksFilter = .mine

    private let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
    private let dayLabels = [
        "2026-05-14": "Thursday, 14 May",
        "2026-05-15": "Friday, 15 May",
        "2026-05-16": "Saturday, 16 May",
    ]

    private var filteredSessions: [Session] {
        switch filter {
        case .mine:
            return store.myPickedSessions
        case .ben:
            return store.currentUser == .ben
                ? store.myPickedSessions
                : store.matePickedSessions
        case .ron:
            return store.currentUser == .ron
                ? store.myPickedSessions
                : store.matePickedSessions
        case .both:
            return store.bothPickedSessions
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter pills
                HStack(spacing: 8) {
                    ForEach(PicksFilter.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filter = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(CNFonts.sans(13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    filter == option
                                        ? CNColors.navy(for: colorScheme)
                                        : CNColors.surfaceSecondary(for: colorScheme)
                                )
                                .foregroundStyle(
                                    filter == option
                                        ? .white
                                        : CNColors.textPrimary(for: colorScheme)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 12)

                if filteredSessions.isEmpty {
                    emptyState
                } else {
                    pickedList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CNColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("My Picks")
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: filter == .mine ? "star" : "person.2")
                .font(.system(size: 48))
                .foregroundStyle(CNColors.gold(for: colorScheme).opacity(0.4))
            Text(emptyMessage)
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            if filter == .mine {
                Text("Browse the Schedule and tap the star to build your programme.")
                    .font(CNFonts.body)
                    .foregroundStyle(CNColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .mine: return "No sessions picked yet"
        case .ben: return "No picks from Ben yet"
        case .ron: return "No picks from Ron yet"
        case .both: return "No sessions in common yet"
        }
    }

    private var pickedList: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Summary header (only for Mine)
                if filter == .mine {
                    HStack(spacing: 12) {
                        ForEach(dates, id: \.self) { date in
                            let count = store.pickCount(for: date)
                            let short = date == "2026-05-14" ? "Thu" : date == "2026-05-15" ? "Fri" : "Sat"
                            Text("\(short): \(count)")
                                .font(CNFonts.sans(13, weight: .medium))
                                .foregroundStyle(
                                    count > 0
                                        ? CNColors.navy(for: colorScheme)
                                        : CNColors.textSecondary
                                )
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Day sections
                ForEach(dates, id: \.self) { date in
                    let daySessions = filteredSessions.filter { $0.date == date }
                    if !daySessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayLabels[date] ?? date)
                                .font(CNFonts.title2)
                                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            ForEach(daySessions) { session in
                                NavigationLink(value: session.id) {
                                    SessionCardView(session: session, showTime: true)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .refreshable {
            await store.syncPicks()
        }
    }
}
