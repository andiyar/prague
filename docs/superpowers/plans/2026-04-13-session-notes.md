# Session Notes V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-session Markdown notes with photo capture, in-app rendered preview (MarkdownUI), iCloud Drive sync, and conference report export.

**Architecture:** Notes are stored as `.md` files with YAML front matter in iCloud Drive (`iCloud.com.wheresBen.ConferenceNav/Documents/notes/`), making them accessible from Mac/iPad via Files/Obsidian/Typora. Photos are saved alongside in a `photos/` folder, referenced from Markdown via relative paths. A `NotesStore` (Observable) manages CRUD and file I/O on a background queue. The `MarkdownUI` SPM package renders notes in-app with a custom theme matching the conference design palette.

**Tech Stack:** SwiftUI, MarkdownUI (SPM), iCloud Drive (FileManager + NSUbiquitousContainers), PhotosUI (PHPickerViewController), UIImagePickerController (camera)

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `ConferenceNav/Models/SessionNote.swift` | Note model with YAML front matter serialisation |
| Create | `ConferenceNav/Services/NotesStore.swift` | Observable store: CRUD, file I/O, iCloud container |
| Create | `ConferenceNav/Views/NoteEditorView.swift` | Edit/preview toggle with TextEditor + MarkdownUI |
| Create | `ConferenceNav/Views/NoteListView.swift` | All notes list for Extras tab (session notes menu) |
| Create | `ConferenceNav/Views/PhotoPickerView.swift` | Camera + photo library picker, saves to photos/ |
| Create | `ConferenceNav/Design/MarkdownTheme.swift` | Custom MarkdownUI theme using CNColors/CNFonts |
| Modify | `ConferenceNav/Views/SessionDetailView.swift` | Add "Notes" button to session header |
| Modify | `ConferenceNav/Views/ExtrasView.swift` | Wire up Session Notes row (remove "Coming soon") |
| Modify | `ConferenceNav/Views/ExportView.swift` | Add conference report export from notes |
| Modify | `ConferenceNav/ConferenceNavApp.swift` | Create and inject NotesStore |
| Modify | `ConferenceNav/project.yml` | Add MarkdownUI SPM dependency, iCloud entitlement |
| Create | `ConferenceNav/ConferenceNav.entitlements` | iCloud Drive entitlement plist |

---

## Task 1: Add MarkdownUI SPM Dependency

**Files:**
- Modify: `ConferenceNav/project.yml`

This task adds the MarkdownUI package to the xcodegen spec and regenerates the project.

- [ ] **Step 1: Update project.yml with SPM package**

```yaml
name: ConferenceNav
options:
  bundleIdPrefix: com.wheresBen
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    INFOPLIST_KEY_CFBundleDisplayName: "EAPragueC 2026"
    MARKETING_VERSION: "1.1"
    CURRENT_PROJECT_VERSION: "2"

packages:
  swift-markdown-ui:
    url: https://github.com/gonzalezreal/swift-markdown-ui
    from: "2.4.0"

targets:
  ConferenceNav:
    type: application
    platform: iOS
    sources:
      - path: ConferenceNavApp.swift
      - path: Models
      - path: Services
      - path: Design
      - path: Views
      - path: Resources
        buildPhase: resources
      - path: Assets.xcassets
    dependencies:
      - package: swift-markdown-ui
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wheresBen.ConferenceNav
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: true
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_CFBundleDisplayName: "EAPragueC 2026"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        GENERATE_INFOPLIST_FILE: true
        DEVELOPMENT_TEAM: ""
        CODE_SIGN_STYLE: Automatic
        CODE_SIGNING_ALLOWED: "$(inherited)"
        CODE_SIGNING_REQUIRED: NO
```

- [ ] **Step 2: Regenerate Xcode project and resolve packages**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -resolvePackageDependencies
```

Expected: Package resolved successfully, project regenerated.

- [ ] **Step 3: Verify build**

```bash
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/project.yml ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add MarkdownUI SPM dependency for session notes"
```

---

## Task 2: Create SessionNote Model

**Files:**
- Create: `ConferenceNav/Models/SessionNote.swift`

The note model maps 1:1 to a Markdown file with YAML front matter. Each note belongs to one session. Photo filenames are stored in an array — the actual images live in the `photos/` directory.

- [ ] **Step 1: Create SessionNote model**

```swift
// ConferenceNav/Models/SessionNote.swift
import Foundation

struct SessionNote: Identifiable, Equatable {
    let id: UUID
    let sessionId: Int
    let sessionTitle: String
    let sessionDate: String      // "2026-05-14"
    let sessionTime: String      // "09:00-10:30"
    let sessionVenue: String
    var body: String             // Markdown content
    var photoFilenames: [String] // Relative filenames in photos/ dir
    var lastModified: Date

    init(
        id: UUID = UUID(),
        sessionId: Int,
        sessionTitle: String,
        sessionDate: String,
        sessionTime: String,
        sessionVenue: String,
        body: String = "",
        photoFilenames: [String] = [],
        lastModified: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.sessionDate = sessionDate
        self.sessionTime = sessionTime
        self.sessionVenue = sessionVenue
        self.body = body
        self.photoFilenames = photoFilenames
        self.lastModified = lastModified
    }

    /// Filename for this note's Markdown file
    var filename: String {
        // e.g. "session-42.md"
        "session-\(sessionId).md"
    }

    // MARK: - YAML Front Matter Serialisation

    /// Serialise to Markdown file content with YAML front matter
    func toMarkdown() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        var md = "---\n"
        md += "session_id: \(sessionId)\n"
        md += "title: \"\(sessionTitle.replacingOccurrences(of: "\"", with: "\\\""))\"\n"
        md += "date: \(sessionDate)\n"
        md += "time: \(sessionTime)\n"
        md += "venue: \(sessionVenue)\n"
        if !photoFilenames.isEmpty {
            md += "photos:\n"
            for photo in photoFilenames {
                md += "  - \(photo)\n"
            }
        }
        md += "last_modified: \(dateFormatter.string(from: lastModified))\n"
        md += "---\n\n"
        md += "# \(sessionTitle)\n\n"
        md += body
        return md
    }

    /// Parse a Markdown file with YAML front matter back into a SessionNote
    static func fromMarkdown(_ content: String, id: UUID = UUID()) -> SessionNote? {
        guard content.hasPrefix("---\n") else { return nil }

        let parts = content.split(separator: "---\n", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }

        let yamlBlock = String(parts[1])
        let bodyBlock = String(parts[2])

        // Parse YAML key-value pairs
        var yaml: [String: String] = [:]
        var photos: [String] = []
        var inPhotos = false

        for line in yamlBlock.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("- ") && inPhotos {
                photos.append(String(trimmed.dropFirst(2)))
                continue
            }
            inPhotos = false

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                if key == "photos" {
                    inPhotos = true
                    continue
                }
                yaml[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        guard let sessionIdStr = yaml["session_id"],
              let sessionId = Int(sessionIdStr) else { return nil }

        // Strip the leading "# Title\n\n" from body if present
        var cleanBody = bodyBlock
        if cleanBody.hasPrefix("\n") {
            cleanBody = String(cleanBody.dropFirst())
        }
        let titlePrefix = "# \(yaml["title"] ?? "")\n\n"
        if cleanBody.hasPrefix(titlePrefix) {
            cleanBody = String(cleanBody.dropFirst(titlePrefix.count))
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return SessionNote(
            id: id,
            sessionId: sessionId,
            sessionTitle: yaml["title"] ?? "Unknown Session",
            sessionDate: yaml["date"] ?? "",
            sessionTime: yaml["time"] ?? "",
            sessionVenue: yaml["venue"] ?? "",
            body: cleanBody,
            photoFilenames: photos,
            lastModified: dateFormatter.date(from: yaml["last_modified"] ?? "") ?? Date()
        )
    }
}
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
cd ConferenceNav && xcodegen generate
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/Models/SessionNote.swift ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add SessionNote model with YAML front matter serialisation"
```

---

## Task 3: Create NotesStore Service

**Files:**
- Create: `ConferenceNav/Services/NotesStore.swift`

The store manages notes in-memory with iCloud Drive persistence. Falls back to local Documents if iCloud is unavailable. File I/O runs on a background queue.

- [ ] **Step 1: Create NotesStore**

```swift
// ConferenceNav/Services/NotesStore.swift
import SwiftUI
import UIKit

@Observable
class NotesStore {
    private(set) var notes: [SessionNote] = []
    private(set) var isLoading = false

    private let userId: String
    private let fileQueue = DispatchQueue(label: "com.wheresBen.ConferenceNav.notes", qos: .userInitiated)

    init(userId: String) {
        self.userId = userId
        loadNotes()
    }

    // MARK: - Public API

    /// Get or create a note for a session
    func note(for session: Session) -> SessionNote {
        if let existing = notes.first(where: { $0.sessionId == session.id }) {
            return existing
        }
        return SessionNote(
            sessionId: session.id,
            sessionTitle: session.title,
            sessionDate: session.date,
            sessionTime: "\(session.startsAt)-\(session.endsAt)",
            sessionVenue: session.venue
        )
    }

    /// Check if a session has a note with content
    func hasNote(for sessionId: Int) -> Bool {
        guard let note = notes.first(where: { $0.sessionId == sessionId }) else { return false }
        return !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !note.photoFilenames.isEmpty
    }

    /// Save a note (creates or updates)
    func save(_ note: SessionNote) {
        var updated = note
        updated.lastModified = Date()

        if let index = notes.firstIndex(where: { $0.sessionId == note.sessionId }) {
            notes[index] = updated
        } else {
            notes.append(updated)
        }
        persistNote(updated)
    }

    /// Delete a note and its photos
    func delete(_ note: SessionNote) {
        notes.removeAll { $0.sessionId == note.sessionId }
        deleteNoteFile(note)
    }

    /// Save a photo for a session, returns the filename
    func savePhoto(_ image: UIImage, for note: SessionNote) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let filename = "session-\(note.sessionId)-\(UUID().uuidString.prefix(8)).jpg"
        let photosDir = photosDirectory()

        do {
            try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
            let fileURL = photosDir.appendingPathComponent(filename)
            try data.write(to: fileURL)
            return filename
        } catch {
            print("NotesStore: Failed to save photo: \(error)")
            return nil
        }
    }

    /// Load a photo by filename
    func loadPhoto(filename: String) -> UIImage? {
        let url = photosDirectory().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Delete a photo file
    func deletePhoto(filename: String) {
        let url = photosDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// All notes sorted by session date/time
    var sortedNotes: [SessionNote] {
        notes.sorted { a, b in
            if a.sessionDate != b.sessionDate { return a.sessionDate < b.sessionDate }
            return a.sessionTime < b.sessionTime
        }
    }

    /// Notes that have content (for export/listing)
    var notesWithContent: [SessionNote] {
        sortedNotes.filter {
            !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.photoFilenames.isEmpty
        }
    }

    // MARK: - Export

    /// Generate a combined conference report from all notes
    func exportConferenceReport(pickedSessions: [Session]) -> String {
        let dates = ["2026-05-14", "2026-05-15", "2026-05-16"]
        let dayLabels = [
            "2026-05-14": "Wednesday, 14 May",
            "2026-05-15": "Thursday, 15 May",
            "2026-05-16": "Friday, 16 May",
        ]

        var md = "# EAPC 2026 Conference Report\n\n"
        md += "*Generated \(formattedDate(Date()))*\n\n"
        md += "---\n\n"

        for date in dates {
            let daySessions = pickedSessions.filter { $0.date == date }
            if daySessions.isEmpty { continue }

            md += "## \(dayLabels[date] ?? date)\n\n"

            for session in daySessions {
                md += "### \(session.startsAt)-\(session.endsAt) · \(session.venue)\n"
                md += "**\(session.title)** (\(session.type.rawValue))\n\n"

                if let note = notes.first(where: { $0.sessionId == session.id }),
                   !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    md += note.body
                    md += "\n\n"

                    if !note.photoFilenames.isEmpty {
                        md += "*Photos: \(note.photoFilenames.joined(separator: ", "))*\n\n"
                    }
                } else {
                    md += "*No notes recorded.*\n\n"
                }
            }
        }

        return md
    }

    // MARK: - File I/O

    private func notesDirectory() -> URL {
        let base = containerURL()
        return base.appendingPathComponent("notes")
    }

    private func photosDirectory() -> URL {
        let base = containerURL()
        return base.appendingPathComponent("photos")
    }

    /// Returns iCloud Drive Documents URL if available, otherwise local Documents
    private func containerURL() -> URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            return iCloudURL
        }
        // Fallback to local Documents
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func loadNotes() {
        isLoading = true
        fileQueue.async { [weak self] in
            guard let self else { return }
            let dir = self.notesDirectory()

            guard FileManager.default.fileExists(atPath: dir.path) else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            do {
                let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "md" }

                var loaded: [SessionNote] = []
                for file in files {
                    let content = try String(contentsOf: file, encoding: .utf8)
                    if let note = SessionNote.fromMarkdown(content) {
                        loaded.append(note)
                    }
                }

                DispatchQueue.main.async {
                    self.notes = loaded
                    self.isLoading = false
                }
            } catch {
                print("NotesStore: Failed to load notes: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }

    private func persistNote(_ note: SessionNote) {
        fileQueue.async { [weak self] in
            guard let self else { return }
            let dir = self.notesDirectory()

            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let fileURL = dir.appendingPathComponent(note.filename)
                try note.toMarkdown().write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("NotesStore: Failed to save note: \(error)")
            }
        }
    }

    private func deleteNoteFile(_ note: SessionNote) {
        fileQueue.async { [weak self] in
            guard let self else { return }
            let fileURL = self.notesDirectory().appendingPathComponent(note.filename)
            try? FileManager.default.removeItem(at: fileURL)

            // Also delete associated photos
            for photo in note.photoFilenames {
                let photoURL = self.photosDirectory().appendingPathComponent(photo)
                try? FileManager.default.removeItem(at: photoURL)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: date)
    }
}
```

- [ ] **Step 2: Regenerate and build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Services/NotesStore.swift ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add NotesStore with iCloud Drive persistence and photo management"
```

---

## Task 4: Create MarkdownUI Custom Theme

**Files:**
- Create: `ConferenceNav/Design/MarkdownTheme.swift`

A custom MarkdownUI theme that uses the app's CNColors and CNFonts for consistent rendering.

- [ ] **Step 1: Create theme file**

```swift
// ConferenceNav/Design/MarkdownTheme.swift
import MarkdownUI
import SwiftUI

extension Theme {
    /// Conference-themed Markdown rendering
    static func conference(colorScheme: ColorScheme) -> Theme {
        .gitHub
            .text {
                ForegroundColor(CNColors.textPrimary(for: colorScheme))
                FontSize(15)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                ForegroundColor(CNColors.teal(for: colorScheme))
            }
            .link {
                ForegroundColor(CNColors.teal(for: colorScheme))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(22)
                        ForegroundColor(CNColors.navy(for: colorScheme))
                    }
                    .markdownMargin(top: 16, bottom: 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(18)
                        ForegroundColor(CNColors.navy(for: colorScheme))
                    }
                    .markdownMargin(top: 12, bottom: 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(16)
                        ForegroundColor(CNColors.textPrimary(for: colorScheme))
                    }
                    .markdownMargin(top: 10, bottom: 4)
            }
            .blockquote { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontStyle(.italic)
                        ForegroundColor(CNColors.textSecondary)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(CNColors.teal(for: colorScheme).opacity(0.4))
                            .frame(width: 3)
                    }
                    .markdownMargin(top: 8, bottom: 8)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(12)
                    .background(CNColors.surfaceSecondary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .markdownMargin(top: 8, bottom: 8)
            }
    }
}
```

- [ ] **Step 2: Regenerate and build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Design/MarkdownTheme.swift ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add custom MarkdownUI theme with conference design palette"
```

---

## Task 5: Create Note Editor View

**Files:**
- Create: `ConferenceNav/Views/NoteEditorView.swift`

The main note editing/viewing screen. Two modes: **Edit** (TextEditor for raw Markdown) and **Preview** (MarkdownUI rendered). Toolbar toggle between modes. Photo attachment button. Auto-saves on dismiss.

- [ ] **Step 1: Create NoteEditorView**

```swift
// ConferenceNav/Views/NoteEditorView.swift
import SwiftUI
import MarkdownUI
import PhotosUI

struct NoteEditorView: View {
    let session: Session

    @Environment(NotesStore.self) var notesStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var noteBody: String = ""
    @State private var photoFilenames: [String] = []
    @State private var isPreview = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPhotoSource = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Session context header
                sessionHeader

                Divider()

                // Editor or preview
                if isPreview {
                    previewMode
                } else {
                    editMode
                }

                // Photo strip
                if !photoFilenames.isEmpty {
                    photoStrip
                }
            }
            .background(CNColors.background(for: colorScheme))
            .navigationTitle("Session Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation { isPreview.toggle() }
                    } label: {
                        Image(systemName: isPreview ? "pencil" : "eye")
                            .foregroundStyle(CNColors.navy(for: colorScheme))
                    }

                    Button {
                        showingPhotoSource = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(CNColors.navy(for: colorScheme))
                    }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingPhotoSource) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView { image in
                    attachPhoto(image)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    attachPhoto(image)
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                let note = notesStore.note(for: session)
                noteBody = note.body
                photoFilenames = note.photoFilenames
            }
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(CNFonts.headline)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(session.dayLabel)
                    .font(CNFonts.caption)
                Text("·")
                Text("\(session.startsAt)-\(session.endsAt)")
                    .font(CNFonts.timeSmall)
                Text("·")
                Text(session.venue)
                    .font(CNFonts.caption)
            }
            .foregroundStyle(CNColors.teal(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(CNColors.surface(for: colorScheme))
    }

    // MARK: - Edit Mode

    private var editMode: some View {
        VStack(spacing: 0) {
            // Markdown hint bar
            HStack(spacing: 16) {
                markdownHint("**bold**")
                markdownHint("*italic*")
                markdownHint("## heading")
                markdownHint("- list")
                markdownHint("> quote")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(CNColors.surfaceSecondary(for: colorScheme))

            TextEditor(text: $noteBody)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
    }

    private func markdownHint(_ text: String) -> some View {
        Text(text)
            .font(CNFonts.mono(11))
            .foregroundStyle(CNColors.textSecondary)
    }

    // MARK: - Preview Mode

    private var previewMode: some View {
        ScrollView {
            if noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 60)
                    Text("No notes yet")
                        .font(CNFonts.title2)
                        .foregroundStyle(CNColors.textSecondary)
                    Text("Tap the pencil icon to start writing.")
                        .font(CNFonts.body)
                        .foregroundStyle(CNColors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Markdown(noteBody)
                    .markdownTheme(.conference(colorScheme: colorScheme))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Photos (\(photoFilenames.count))")
                .font(CNFonts.caption)
                .foregroundStyle(CNColors.textSecondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photoFilenames, id: \.self) { filename in
                        if let image = notesStore.loadPhoto(filename: filename) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        removePhoto(filename)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
        .background(CNColors.surface(for: colorScheme))
    }

    // MARK: - Actions

    private func attachPhoto(_ image: UIImage) {
        if let filename = notesStore.savePhoto(image, for: notesStore.note(for: session)) {
            photoFilenames.append(filename)
        }
    }

    private func removePhoto(_ filename: String) {
        photoFilenames.removeAll { $0 == filename }
        notesStore.deletePhoto(filename: filename)
    }

    private func saveAndDismiss() {
        var note = notesStore.note(for: session)
        note.body = noteBody
        note.photoFilenames = photoFilenames
        // Only save if there's actual content
        if !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photoFilenames.isEmpty {
            notesStore.save(note)
        } else if notesStore.hasNote(for: session.id) {
            // Had a note before but now it's empty — delete
            notesStore.delete(note)
        }
        dismiss()
    }
}
```

- [ ] **Step 2: Regenerate and build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: Will fail — `PhotoPickerView` and `CameraView` don't exist yet. That's fine, they're created in Task 6.

- [ ] **Step 3: Commit (with build errors — will be resolved in Task 6)**

```bash
git add ConferenceNav/Views/NoteEditorView.swift ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add NoteEditorView with edit/preview toggle and photo strip (WIP)"
```

---

## Task 6: Create Photo Picker and Camera Views

**Files:**
- Create: `ConferenceNav/Views/PhotoPickerView.swift`

PHPicker for photo library and UIImagePickerController for camera.

- [ ] **Step 1: Create PhotoPickerView and CameraView**

```swift
// ConferenceNav/Views/PhotoPickerView.swift
import SwiftUI
import PhotosUI

struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 5
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void

        init(onPick: @escaping (UIImage) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            self?.onPick(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
```

- [ ] **Step 2: Add camera usage description to project.yml**

Add to the target settings in `project.yml`:

```yaml
        INFOPLIST_KEY_NSCameraUsageDescription: "Take photos of sessions, posters, and slides"
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "Attach photos from your library to session notes"
```

- [ ] **Step 3: Regenerate and build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED (NoteEditorView can now resolve PhotoPickerView and CameraView)

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/Views/PhotoPickerView.swift ConferenceNav/project.yml ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add photo picker and camera views for session notes"
```

---

## Task 7: Create Notes List View for Extras Tab

**Files:**
- Create: `ConferenceNav/Views/NoteListView.swift`

A list of all sessions that have notes, accessed from the Extras tab. Shows session title, date, preview of note text, photo count.

- [ ] **Step 1: Create NoteListView**

```swift
// ConferenceNav/Views/NoteListView.swift
import SwiftUI

struct NoteListView: View {
    @Environment(NotesStore.self) var notesStore
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    @State private var editingSession: Session?

    var body: some View {
        Group {
            if notesStore.notesWithContent.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CNColors.background(for: colorScheme))
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Session Notes")
        .sheet(item: $editingSession) { session in
            NoteEditorView(session: session)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(CNColors.teal(for: colorScheme).opacity(0.4))
            Text("No notes yet")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            Text("Open a session and tap the notes icon\nto start capturing your thoughts.")
                .font(CNFonts.body)
                .foregroundStyle(CNColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var notesList: some View {
        List {
            ForEach(notesStore.notesWithContent) { note in
                Button {
                    if let session = store.sessions.first(where: { $0.id == note.sessionId }) {
                        editingSession = session
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.sessionTitle)
                            .font(CNFonts.headline)
                            .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Text(note.sessionDate)
                                .font(CNFonts.timeSmall)
                            Text("·")
                            Text(note.sessionTime)
                                .font(CNFonts.timeSmall)
                            Text("·")
                            Text(note.sessionVenue)
                                .font(CNFonts.caption)
                        }
                        .foregroundStyle(CNColors.teal(for: colorScheme))

                        // Note preview
                        Text(note.body.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(CNFonts.body)
                            .foregroundStyle(CNColors.textSecondary)
                            .lineLimit(2)

                        if !note.photoFilenames.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                Text("\(note.photoFilenames.count) photo\(note.photoFilenames.count == 1 ? "" : "s")")
                                    .font(CNFonts.small)
                            }
                            .foregroundStyle(CNColors.gold(for: colorScheme))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .onDelete { offsets in
                let sorted = notesStore.notesWithContent
                for index in offsets {
                    notesStore.delete(sorted[index])
                }
            }
        }
        .listStyle(.plain)
    }
}

// Make Session conform to Identifiable (it already does) + Hashable for .sheet(item:)
extension Session: Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

Note: If `Session` already conforms to `Hashable`, remove the extension. Check `ConferenceNav/Models/Session.swift` — if it only conforms to `Codable, Identifiable`, add the `Hashable` conformance.

- [ ] **Step 2: Regenerate and build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/NoteListView.swift ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add NoteListView for browsing all session notes"
```

---

## Task 8: Wire Session Notes into SessionDetailView

**Files:**
- Modify: `ConferenceNav/Views/SessionDetailView.swift`

Add a "Notes" button to the session detail header, next to the pick button. Shows a badge dot if notes exist.

- [ ] **Step 1: Add notes button to SessionDetailView**

In `SessionDetailView`, add a `@State private var showingNoteEditor = false` property and an `@Environment(NotesStore.self) var notesStore`.

Add the notes button in the pick + badges row (after `MateBadges`):

```swift
// In the HStack with PickButton and MateBadges, add:
Button {
    showingNoteEditor = true
} label: {
    HStack(spacing: 4) {
        Image(systemName: notesStore.hasNote(for: session.id) ? "note.text" : "note.text.badge.plus")
            .font(.system(size: 16))
        if notesStore.hasNote(for: session.id) {
            Circle()
                .fill(CNColors.teal(for: colorScheme))
                .frame(width: 6, height: 6)
        }
    }
    .foregroundStyle(CNColors.teal(for: colorScheme))
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(CNColors.surfaceSecondary(for: colorScheme))
    .clipShape(Capsule())
}
```

Add the sheet modifier to the ScrollView:

```swift
.sheet(isPresented: $showingNoteEditor) {
    NoteEditorView(session: session)
}
```

- [ ] **Step 2: Build and verify**

```bash
cd ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/SessionDetailView.swift
git commit -m "feat: add notes button to session detail view"
```

---

## Task 9: Wire NotesStore into App and Extras Tab

**Files:**
- Modify: `ConferenceNav/ConferenceNavApp.swift`
- Modify: `ConferenceNav/Views/ExtrasView.swift`

Inject NotesStore into the environment and activate the Session Notes row in Extras.

- [ ] **Step 1: Add NotesStore to ConferenceNavApp**

In `ConferenceNavApp.swift`, add:

```swift
@State private var notesStore: NotesStore?
```

In the `.environment()` chain, add:

```swift
.environment(notesStore ?? NotesStore(userId: savedUserId ?? "default"))
```

In the `.onAppear` block where `contactStore` is created, also create `notesStore`:

```swift
if notesStore == nil {
    notesStore = NotesStore(userId: id)
}
```

In the `UserPickerView` onSelect closure, also create `notesStore`:

```swift
notesStore = NotesStore(userId: id)
```

- [ ] **Step 2: Update ExtrasView — activate Session Notes**

Replace the disabled Session Notes section in `ExtrasView.swift`:

```swift
// Replace the static "Coming soon" label with:
NavigationLink(value: "notes") {
    Label {
        VStack(alignment: .leading, spacing: 2) {
            Text("Session Notes")
                .font(CNFonts.headline)
                .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            Text("\(notesStore.notesWithContent.count) notes")
                .font(CNFonts.caption)
                .foregroundStyle(CNColors.textSecondary)
        }
    } icon: {
        Image(systemName: "note.text")
            .foregroundStyle(CNColors.teal(for: colorScheme))
            .font(.system(size: 20))
    }
    .padding(.vertical, 6)
}
```

Add `NotesStore` environment and the navigation destination:

```swift
@Environment(NotesStore.self) var notesStore
```

In the `.navigationDestination(for: String.self)` switch, add:

```swift
case "notes":
    NoteListView()
```

Remove the `.opacity(0.5)` from the Session Notes row.

- [ ] **Step 3: Build and verify**

```bash
cd ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/ConferenceNavApp.swift ConferenceNav/Views/ExtrasView.swift
git commit -m "feat: wire NotesStore into app and activate Session Notes in Extras"
```

---

## Task 10: Add Conference Report Export

**Files:**
- Modify: `ConferenceNav/Views/ExportView.swift`

Replace the "Session Notes export coming in V2" placeholder with two export options: Conference Report (picked sessions + notes combined) and Raw Notes (all notes as individual files in a zip — future, for now just the report).

- [ ] **Step 1: Update ExportView with conference report**

In `ExportView.swift`, add `@Environment(NotesStore.self) var notesStore`.

Replace the V2 placeholder section:

```swift
Section {
    Text("Session Notes export coming in V2")
        .font(CNFonts.caption)
        .foregroundStyle(CNColors.textSecondary)
}
```

With:

```swift
Section {
    exportRow(
        title: "Conference Report",
        subtitle: "Picks + notes combined",
        icon: "doc.richtext",
        iconColor: CNColors.navy(for: colorScheme),
        disabled: store.myPickedSessions.isEmpty
    ) {
        exportFile(
            content: notesStore.exportConferenceReport(pickedSessions: store.myPickedSessions),
            filename: "EAPC-2026-Conference-Report.md"
        )
    }

    exportRow(
        title: "All Notes (Markdown)",
        subtitle: "\(notesStore.notesWithContent.count) notes",
        icon: "note.text",
        iconColor: CNColors.teal(for: colorScheme),
        disabled: notesStore.notesWithContent.isEmpty
    ) {
        exportFile(
            content: exportAllNotes(),
            filename: "EAPC-2026-Notes.md"
        )
    }
} header: {
    Text("Notes & Report")
}
```

Add the `exportAllNotes` function:

```swift
private func exportAllNotes() -> String {
    var md = "# Session Notes — EAPC 2026\n\n"
    for note in notesStore.notesWithContent {
        md += "## \(note.sessionTitle)\n"
        md += "*\(note.sessionDate) · \(note.sessionTime) · \(note.sessionVenue)*\n\n"
        md += note.body
        md += "\n\n---\n\n"
    }
    return md
}
```

- [ ] **Step 2: Build and verify**

```bash
cd ConferenceNav && xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ConferenceNav/Views/ExportView.swift
git commit -m "feat: add conference report and notes export"
```

---

## Task 11: Add iCloud Entitlements (Optional — For Real Devices)

**Files:**
- Create: `ConferenceNav/ConferenceNav.entitlements`
- Modify: `ConferenceNav/project.yml`

iCloud Drive requires entitlements and a container. On simulator, `url(forUbiquityContainerIdentifier:)` returns nil and NotesStore falls back to local Documents — which is fine for testing. This task sets up iCloud for real devices.

- [ ] **Step 1: Create entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.wheresBen.ConferenceNav</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.wheresBen.ConferenceNav</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Add NSUbiquitousContainers to project.yml Info.plist keys**

Add to target settings:

```yaml
        INFOPLIST_KEY_NSUbiquitousContainers: |
          <dict>
            <key>iCloud.com.wheresBen.ConferenceNav</key>
            <dict>
              <key>NSUbiquitousContainerIsDocumentScopePublic</key>
              <true/>
              <key>NSUbiquitousContainerName</key>
              <string>EAPragueC 2026</string>
              <key>NSUbiquitousContainerSupportedFolderLevels</key>
              <string>Any</string>
            </dict>
          </dict>
        CODE_SIGN_ENTITLEMENTS: ConferenceNav.entitlements
```

**Note:** The `NSUbiquitousContainers` Info.plist key may need to be set manually in Xcode rather than via xcodegen, as it's a nested dictionary. If xcodegen doesn't handle it, add it directly to the generated Info.plist or use an `info` section in project.yml instead. The entitlements file approach is more reliable — set it up in Xcode's Signing & Capabilities → iCloud → iCloud Documents after generating the project.

- [ ] **Step 3: Regenerate and build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED (entitlements only enforced on device)

- [ ] **Step 4: Commit**

```bash
git add ConferenceNav/ConferenceNav.entitlements ConferenceNav/project.yml ConferenceNav/ConferenceNav.xcodeproj
git commit -m "feat: add iCloud Drive entitlements for session notes sync"
```

---

## Task 12: Final Integration Build and Push

- [ ] **Step 1: Full clean build**

```bash
cd ConferenceNav && xcodegen generate
xcodebuild -project ConferenceNav.xcodeproj -scheme ConferenceNav -destination 'platform=iOS Simulator,name=iPhone 16' -quiet CODE_SIGNING_ALLOWED=NO clean build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Push to remote**

```bash
git push
```

- [ ] **Step 3: Update CLAUDE.md with V2 status**

Add to the EAPragueC 2026 section in `CLAUDE.md`:

```markdown
### V2 Features (April 2026)
- **Session Notes**: Markdown notes per session with YAML front matter, stored in iCloud Drive
- **Photo Capture**: Camera + photo library, saved alongside notes
- **Markdown Preview**: In-app rendered preview via MarkdownUI (custom conference theme)
- **Conference Report Export**: Combined Markdown report from picks + notes
- **Notes accessible from**: Session detail (notes button), Extras tab (notes list), Export tab
```

- [ ] **Step 4: Commit and push**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with V2 session notes features"
git push
```
