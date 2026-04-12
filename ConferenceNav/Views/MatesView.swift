import SwiftUI

struct MatesView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    enum MateFilter: String, CaseIterable {
        case ben = "Ben's Picks"
        case ron = "Ron's Picks"
        case both = "Both"
    }

    @State private var filter: MateFilter = .ron

    private let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
    private let dayLabels = [
        "2026-05-14": "Thursday, 14 May",
        "2026-05-15": "Friday, 15 May",
        "2026-05-16": "Saturday, 16 May",
    ]

    private var defaultFilter: MateFilter {
        store.currentUser == .ben ? .ron : .ben
    }

    private var filteredSessions: [Session] {
        switch filter {
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
                // User pills
                HStack(spacing: 8) {
                    ForEach(MateFilter.allCases, id: \.self) { option in
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
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundStyle(CNColors.textSecondary.opacity(0.4))
                        Text(filter == .both ? "No sessions in common yet" : "No picks yet")
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CNColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Mates")
            .navigationDestination(for: Int.self) { sessionId in
                if let session = store.sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
            .onAppear {
                filter = defaultFilter
            }
        }
    }
}
