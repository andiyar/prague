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
