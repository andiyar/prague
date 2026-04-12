import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme
    @State private var showFullDescription = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    TypeBadge(type: session.type)

                    Text(session.title)
                        .font(CNFonts.largeTitle)
                        .foregroundStyle(CNColors.textPrimary(for: colorScheme))

                    // Time + Venue
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        Text("\(session.dayLabel) · \(session.startsAt)-\(session.endsAt)")
                            .font(CNFonts.time)
                        Text("·")
                        Image(systemName: "mappin")
                            .font(.system(size: 14))
                        Text(session.venue)
                            .font(CNFonts.sans(14, weight: .semibold))
                    }
                    .foregroundStyle(CNColors.teal(for: colorScheme))

                    // Pick + badges row
                    HStack(spacing: 12) {
                        PickButton(sessionId: session.id)
                        MateBadges(session: session)
                        Spacer()
                    }

                    // Conflict warning
                    if let conflict = store.conflictingSession(for: session),
                       store.isPicked(session.id) {
                        ConflictBanner(conflictingTitle: conflict.title)
                    }
                }
                .padding(.horizontal, 16)

                // Description
                if !session.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(CNFonts.sans(13, weight: .semibold))
                            .foregroundStyle(CNColors.textSecondary)
                            .textCase(.uppercase)

                        Text(session.description)
                            .font(CNFonts.body)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            .lineLimit(showFullDescription ? nil : 4)

                        if session.description.count > 200 {
                            Button {
                                withAnimation { showFullDescription.toggle() }
                            } label: {
                                Text(showFullDescription ? "Show less" : "Show more")
                                    .font(CNFonts.sans(13, weight: .medium))
                                    .foregroundStyle(CNColors.teal(for: colorScheme))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Presentations
                if !session.presentations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presentations (\(session.presentations.count))")
                            .font(CNFonts.sans(13, weight: .semibold))
                            .foregroundStyle(CNColors.textSecondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)

                        ForEach(session.presentations) { pres in
                            PresentationRow(presentation: pres)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(CNColors.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Presentation Row

struct PresentationRow: View {
    let presentation: Presentation
    @Environment(\.colorScheme) var colorScheme
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if !presentation.startsAt.isEmpty {
                    Text("\(presentation.startsAt)-\(presentation.endsAt)")
                        .font(CNFonts.timeSmall)
                        .foregroundStyle(CNColors.textSecondary)
                        .frame(width: 80, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(CNFonts.sans(14, weight: .semibold))
                        .foregroundStyle(CNColors.textPrimary(for: colorScheme))

                    if !presentation.presenter.isEmpty {
                        Text(presentation.presenter)
                            .font(CNFonts.caption)
                            .foregroundStyle(CNColors.teal(for: colorScheme))
                    }

                    if presentation.authors.count > 1 {
                        Button {
                            withAnimation { expanded.toggle() }
                        } label: {
                            Text(expanded ? "Hide authors" : "\(presentation.authors.count) authors")
                                .font(CNFonts.sans(11, weight: .medium))
                                .foregroundStyle(CNColors.textSecondary)
                        }

                        if expanded {
                            ForEach(presentation.authors, id: \.name) { author in
                                HStack(spacing: 4) {
                                    Text(author.name)
                                        .font(CNFonts.small)
                                        .foregroundStyle(
                                            author.presenting
                                                ? CNColors.teal(for: colorScheme)
                                                : CNColors.textSecondary
                                        )
                                    if !author.organisation.isEmpty {
                                        Text("— \(author.organisation)")
                                            .font(CNFonts.small)
                                            .foregroundStyle(CNColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(CNColors.surfaceSecondary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
