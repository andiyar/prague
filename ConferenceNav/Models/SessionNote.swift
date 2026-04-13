import Foundation

struct SessionNote: Identifiable, Equatable {
    let id: UUID
    let sessionId: Int
    let sessionTitle: String
    let sessionDate: String      // "2026-05-14"
    let sessionTime: String      // "09:00-10:30"
    let sessionVenue: String
    let presentationId: Int?     // nil = session-level note
    let presentationTitle: String
    let presenter: String
    var body: String             // Markdown content
    var photoFilenames: [String] // Relative filenames in photos/ dir
    var lastModified: Date

    /// Unique key for lookups — presentation ID if available, otherwise session ID
    var noteKey: String {
        if let pid = presentationId {
            return "p-\(pid)"
        }
        return "s-\(sessionId)"
    }

    init(
        id: UUID = UUID(),
        sessionId: Int,
        sessionTitle: String,
        sessionDate: String,
        sessionTime: String,
        sessionVenue: String,
        presentationId: Int? = nil,
        presentationTitle: String = "",
        presenter: String = "",
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
        self.presentationId = presentationId
        self.presentationTitle = presentationTitle
        self.presenter = presenter
        self.body = body
        self.photoFilenames = photoFilenames
        self.lastModified = lastModified
    }

    /// Display title — presentation title if available, otherwise session title
    var displayTitle: String {
        presentationTitle.isEmpty ? sessionTitle : presentationTitle
    }

    /// Filename for this note's Markdown file
    var filename: String {
        if let pid = presentationId {
            return "presentation-\(pid).md"
        }
        return "session-\(sessionId).md"
    }

    // MARK: - YAML Front Matter Serialisation

    /// Serialise to Markdown file content with YAML front matter
    func toMarkdown() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        var md = "---\n"
        md += "session_id: \(sessionId)\n"
        md += "session_title: \"\(sessionTitle.replacingOccurrences(of: "\"", with: "\\\""))\"\n"
        md += "date: \(sessionDate)\n"
        md += "time: \(sessionTime)\n"
        md += "venue: \(sessionVenue)\n"
        if let pid = presentationId {
            md += "presentation_id: \(pid)\n"
            md += "presentation_title: \"\(presentationTitle.replacingOccurrences(of: "\"", with: "\\\""))\"\n"
            md += "presenter: \"\(presenter.replacingOccurrences(of: "\"", with: "\\\""))\"\n"
        }
        if !photoFilenames.isEmpty {
            md += "photos:\n"
            for photo in photoFilenames {
                md += "  - \(photo)\n"
            }
        }
        md += "last_modified: \(dateFormatter.string(from: lastModified))\n"
        md += "---\n\n"
        md += "# \(displayTitle)\n\n"
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

        let presentationId = yaml["presentation_id"].flatMap { Int($0) }

        // Strip the leading "# Title\n\n" from body if present
        var cleanBody = bodyBlock
        if cleanBody.hasPrefix("\n") {
            cleanBody = String(cleanBody.dropFirst())
        }
        let title = yaml["presentation_title"] ?? yaml["session_title"] ?? yaml["title"] ?? ""
        let titlePrefix = "# \(title)\n\n"
        if cleanBody.hasPrefix(titlePrefix) {
            cleanBody = String(cleanBody.dropFirst(titlePrefix.count))
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return SessionNote(
            id: id,
            sessionId: sessionId,
            sessionTitle: yaml["session_title"] ?? yaml["title"] ?? "Unknown Session",
            sessionDate: yaml["date"] ?? "",
            sessionTime: yaml["time"] ?? "",
            sessionVenue: yaml["venue"] ?? "",
            presentationId: presentationId,
            presentationTitle: yaml["presentation_title"] ?? "",
            presenter: yaml["presenter"] ?? "",
            body: cleanBody,
            photoFilenames: photos,
            lastModified: dateFormatter.date(from: yaml["last_modified"] ?? "") ?? Date()
        )
    }
}
