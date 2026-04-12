import SwiftUI

struct MyPicksView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    private let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
    private let dayLabels = [
        "2026-05-14": "Thursday, 14 May",
        "2026-05-15": "Friday, 15 May",
        "2026-05-16": "Saturday, 16 May",
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.myPickedSessions.isEmpty {
                    emptyState
                } else {
                    pickedList
                }
            }
            .background(CNColors.background(for: colorScheme))
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
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(CNColors.gold(for: colorScheme).opacity(0.4))
            Text("No sessions picked yet")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            Text("Browse the Schedule and tap the star to build your programme.")
                .font(CNFonts.body)
                .foregroundStyle(CNColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var pickedList: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Summary header
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

                // Day sections
                ForEach(dates, id: \.self) { date in
                    let daySessions = store.myPickedSessions.filter { $0.date == date }
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
