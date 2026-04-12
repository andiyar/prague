import Foundation

struct SearchIndex {
    private struct Entry {
        let sessionId: Int
        let text: String
    }

    private var entries: [Entry] = []

    mutating func build(from sessions: [Session]) {
        entries = sessions.filter(\.isBrowseable).map { session in
            var parts: [String] = []

            parts.append(session.title)
            parts.append(session.description)
            parts.append(session.venue)
            parts.append(session.type.rawValue)

            for pres in session.presentations {
                parts.append(pres.title)
                parts.append(pres.presenter)
                for author in pres.authors {
                    parts.append(author.name)
                    parts.append(author.organisation)
                }
            }

            let combined = parts.joined(separator: " ")
            return Entry(sessionId: session.id, text: normalise(combined))
        }
    }

    func search(_ query: String) -> [Int] {
        let normalised = normalise(query)
        guard !normalised.isEmpty else { return [] }

        let terms = normalised.split(separator: " ").map(String.init)

        return entries
            .filter { entry in
                terms.allSatisfy { term in
                    entry.text.contains(term)
                }
            }
            .map(\.sessionId)
    }

    private func normalise(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
