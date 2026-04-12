import Foundation

actor PicksSyncService {
    private let baseURL = "https://dyxupzbyssvcxjppipnl.supabase.co/rest/v1"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5eHVwemJ5c3N2Y3hqcHBpcG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjc0MTksImV4cCI6MjA4NDUwMzQxOX0._pmFY2kmyUYLauX-BQeELbWziJ4nuXIaxOM5YsUYsBI"

    private struct PickRow: Codable {
        let userId: String
        let sessionId: Int

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case sessionId = "session_id"
        }
    }

    func fetchPicks(userId: String) async throws -> Set<Int> {
        let url = URL(string: "\(baseURL)/conference_picks?user_id=eq.\(userId)&select=session_id")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct Row: Decodable { let session_id: Int }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        return Set(rows.map(\.session_id))
    }

    func addPick(userId: String, sessionId: Int) async throws {
        let url = URL(string: "\(baseURL)/conference_picks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body = PickRow(userId: userId, sessionId: sessionId)
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func removePick(userId: String, sessionId: Int) async throws {
        let url = URL(string: "\(baseURL)/conference_picks?user_id=eq.\(userId)&session_id=eq.\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
