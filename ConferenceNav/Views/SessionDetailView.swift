import SwiftUI

/// Navigation value that carries an optional search query into detail view
struct SessionNav: Hashable {
    let sessionId: Int
    let searchQuery: String

    init(_ sessionId: Int, query: String = "") {
        self.sessionId = sessionId
        self.searchQuery = query
    }
}

struct SessionDetailView: View {
    let session: Session
    var searchQuery: String = ""

    @Environment(ConferenceStore.self) var store
    @Environment(NotesStore.self) var notesStore
    @Environment(NotificationService.self) var notificationService
    @Environment(\.colorScheme) var colorScheme
    @State private var showFullDescription = false
    @State private var showAllPresentations = false
    @State private var showingNoteEditor = false

    private var hasSearch: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var matchingPresentations: [Presentation] {
        guard hasSearch else { return session.presentations }
        let terms = searchQuery.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .split(separator: " ")
            .map(String.init)

        return session.presentations.filter { pres in
            let searchable = ([
                pres.title,
                pres.presenter
            ] + pres.authors.map(\.name) + pres.authors.map(\.organisation))
                .joined(separator: " ")
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)

            return terms.allSatisfy { searchable.contains($0) }
        }
    }

    private var visiblePresentations: [Presentation] {
        if hasSearch && !showAllPresentations {
            return matchingPresentations
        }
        return session.presentations
    }

    private var hasFilteredResults: Bool {
        hasSearch && matchingPresentations.count < session.presentations.count
    }

    // MARK: - iPad reader-mode header

    @ViewBuilder
    private var iPadHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(session.dayLabel) · \(session.startsAt)–\(session.endsAt) · \(session.venue)")
                .font(CNFonts.readerMeta)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)

            Text(session.title)
                .font(CNFonts.readerHeadline)
                .foregroundStyle(CNColors.navy(for: colorScheme))
                .lineSpacing(2)

            if let primaryPresenter = session.presentations.first?.presenter,
               !primaryPresenter.isEmpty {
                Text(primaryPresenter)
                    .font(.custom("New York", size: 15).italic())
                    .foregroundStyle(CNColors.teal(for: colorScheme))
            }
        }
        .padding(.bottom, 12)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                if CNLayout.isPad {
                    VStack(alignment: .leading, spacing: 10) {
                        TypeBadge(type: session.type)
                        iPadHeader
                        // Pick + badges row
                        HStack(spacing: 12) {
                            PickButton(sessionId: session.id)
                            MateBadges(session: session)
                            // Session-level note button only for sessions with no presentations
                            if session.presentations.isEmpty {
                                Button {
                                    showingNoteEditor = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: notesStore.hasNote(forSession: session.id) ? "note.text" : "note.text.badge.plus")
                                            .font(.system(size: 17))
                                        if notesStore.hasNote(forSession: session.id) {
                                            Circle()
                                                .fill(CNColors.teal(for: colorScheme))
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .foregroundStyle(CNColors.teal(for: colorScheme))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(CNColors.surfaceSecondary(for: colorScheme))
                                    .clipShape(Capsule())
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                            } else if notesStore.hasAnyNote(forSession: session.id) {
                                HStack(spacing: 4) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 14))
                                    Circle()
                                        .fill(CNColors.teal(for: colorScheme))
                                        .frame(width: 6, height: 6)
                                }
                                .foregroundStyle(CNColors.teal(for: colorScheme))
                            }
                            Spacer()
                        }
                        // Conflict warning
                        if let conflict = store.conflictingSession(for: session),
                           store.isPicked(session.id) {
                            ConflictBanner(conflictingTitle: conflict.title)
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
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
                        // Session-level note button only for sessions with no presentations
                        if session.presentations.isEmpty {
                            Button {
                                showingNoteEditor = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: notesStore.hasNote(forSession: session.id) ? "note.text" : "note.text.badge.plus")
                                        .font(.system(size: 17))
                                    if notesStore.hasNote(forSession: session.id) {
                                        Circle()
                                            .fill(CNColors.teal(for: colorScheme))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .foregroundStyle(CNColors.teal(for: colorScheme))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(CNColors.surfaceSecondary(for: colorScheme))
                                .clipShape(Capsule())
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                        } else if notesStore.hasAnyNote(forSession: session.id) {
                            // Show indicator that this session has notes on presentations
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 14))
                                Circle()
                                    .fill(CNColors.teal(for: colorScheme))
                                    .frame(width: 6, height: 6)
                            }
                            .foregroundStyle(CNColors.teal(for: colorScheme))
                        }
                        Spacer()
                    }

                    // Conflict warning
                    if let conflict = store.conflictingSession(for: session),
                       store.isPicked(session.id) {
                        ConflictBanner(conflictingTitle: conflict.title)
                    }
                }
                .padding(.horizontal, 16)
                } // end iPhone header

                // Venue map thumbnail — tap to open full venue map
                VenueMapThumbnail(venue: session.venue)
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
                        // Header with match count
                        HStack {
                            if hasSearch && !showAllPresentations {
                                Text("Matching presentations (\(matchingPresentations.count) of \(session.presentations.count))")
                                    .font(CNFonts.sans(13, weight: .semibold))
                                    .foregroundStyle(CNColors.textSecondary)
                                    .textCase(.uppercase)
                            } else {
                                Text("Presentations (\(session.presentations.count))")
                                    .font(CNFonts.sans(13, weight: .semibold))
                                    .foregroundStyle(CNColors.textSecondary)
                                    .textCase(.uppercase)
                            }
                        }
                        .padding(.horizontal, 16)

                        ForEach(visiblePresentations) { pres in
                            PresentationRow(presentation: pres, session: session)
                                .padding(.horizontal, 16)
                        }

                        // Show all / show matches toggle
                        if hasFilteredResults {
                            Button {
                                withAnimation { showAllPresentations.toggle() }
                            } label: {
                                Text(showAllPresentations
                                     ? "Show matches only (\(matchingPresentations.count))"
                                     : "Show all \(session.presentations.count) presentations")
                                    .font(CNFonts.sans(13, weight: .medium))
                                    .foregroundStyle(CNColors.teal(for: colorScheme))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
            .cnPadMaxWidth(CNLayout.MaxWidth.readerBody)
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(session: session, presentation: nil)
                .presentationDetents([.large])
        }
        .background(CNColors.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    notificationService.sendTestNotification(for: session)
                } label: {
                    Image(systemName: "bell.badge")
                }
            }
        }
        #endif
    }
}

// MARK: - Presentation Row

struct PresentationRow: View {
    let presentation: Presentation
    let session: Session
    @Environment(NotesStore.self) var notesStore
    @Environment(\.colorScheme) var colorScheme
    @State private var expanded = false
    @State private var showingNoteEditor = false

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

                    // Note + authors row
                    HStack(spacing: 8) {
                        Button {
                            showingNoteEditor = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: notesStore.hasNote(forPresentation: presentation.id)
                                      ? "note.text" : "note.text.badge.plus")
                                    .font(.system(size: 15))
                                if notesStore.hasNote(forPresentation: presentation.id) {
                                    Circle()
                                        .fill(CNColors.teal(for: colorScheme))
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundStyle(CNColors.teal(for: colorScheme))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(CNColors.surfaceSecondary(for: colorScheme))
                            .clipShape(Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }

                        if presentation.authors.count > 1 {
                            Button {
                                withAnimation { expanded.toggle() }
                            } label: {
                                Text(expanded ? "Hide authors" : "\(presentation.authors.count) authors")
                                    .font(CNFonts.sans(11, weight: .medium))
                                    .foregroundStyle(CNColors.textSecondary)
                            }
                        }
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
        .padding(10)
        .background(CNColors.surfaceSecondary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(session: session, presentation: presentation)
                .presentationDetents([.large])
        }
    }
}
