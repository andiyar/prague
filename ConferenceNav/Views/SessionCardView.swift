import SwiftUI

struct SessionCardView: View {
    let session: Session
    var showTime: Bool = false

    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Type badge + time
                HStack(spacing: 6) {
                    TypeBadge(type: session.type)
                    if showTime {
                        Text(session.timeSlot)
                            .font(CNFonts.timeSmall)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                }

                // Title
                Text(session.title)
                    .font(CNFonts.headline)
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Venue + presentations
                HStack(spacing: 4) {
                    Text(session.venue)
                        .font(CNFonts.caption)
                        .foregroundStyle(CNColors.textSecondary)
                    if session.presentationsCount > 0 {
                        Text("·")
                            .foregroundStyle(CNColors.textSecondary)
                        Text("\(session.presentationsCount) talks")
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.textSecondary)
                    }
                }

                // Badges row
                HStack(spacing: 8) {
                    MateBadges(session: session)

                    if let conflict = store.conflictingSession(for: session),
                       store.isPicked(session.id) {
                        ConflictBanner(conflictingTitle: conflict.title)
                    }
                }
            }

            Spacer()

            PickButton(sessionId: session.id)
        }
        .cnCard(typeColor: CNColors.typeBadgeColor(for: session.type, scheme: colorScheme))
    }
}
