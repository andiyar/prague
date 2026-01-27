import Foundation

/// Supabase REST API client for both apps
actor SupabaseClient {
    static let shared = SupabaseClient()

    private let baseURL = "https://dyxupzbyssvcxjppipnl.supabase.co/rest/v1"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5eHVwemJ5c3N2Y3hqcHBpcG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjc0MTksImV4cCI6MjA4NDUwMzQxOX0._pmFY2kmyUYLauX-BQeELbWziJ4nuXIaxOM5YsUYsBI"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init() {}

    // MARK: - Fetch Methods

    func fetchTripSegments() async throws -> [TripSegment] {
        let url = URL(string: "\(baseURL)/trip_segments?order=start_time.asc")!
        return try await fetch(url: url)
    }

    func fetchActiveOverride() async throws -> StatusOverride? {
        let now = ISO8601DateFormatter().string(from: Date())
        let url = URL(string: "\(baseURL)/status_override?expires_at=gt.\(now)&order=created_at.desc&limit=1")!
        let overrides: [StatusOverride] = try await fetch(url: url)
        return overrides.first
    }

    func fetchConfig() async throws -> TripConfig {
        let url = URL(string: "\(baseURL)/config")!
        let rows: [ConfigRow] = try await fetch(url: url)
        return TripConfig(from: rows)
    }

    // MARK: - Insert/Update Methods

    func postStatusOverride(
        emoji: String,
        statusText: String,
        kidsText: String,
        note: String?,
        latitude: Double?,
        longitude: Double?
    ) async throws {
        let url = URL(string: "\(baseURL)/status_override")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let expiresAt = Calendar.current.date(byAdding: .hour, value: 6, to: Date())!

        let override = StatusOverrideInsert(
            id: 1, // Always use ID 1 to replace previous
            statusEmoji: emoji,
            statusText: statusText,
            kidsText: kidsText,
            note: note,
            lat: latitude,
            lng: longitude,
            expiresAt: expiresAt
        )

        request.httpBody = try encoder.encode(override)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.postFailed
        }
    }

    func clearStatusOverride() async throws {
        let url = URL(string: "\(baseURL)/status_override?id=eq.1")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.deleteFailed
        }
    }

    func registerPushToken(deviceId: String, token: String) async throws {
        let url = URL(string: "\(baseURL)/push_tokens")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body = ["device_id": deviceId, "token": token]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.postFailed
        }
    }

    // MARK: - Private Helpers

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.fetchFailed
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum SupabaseError: Error, LocalizedError {
    case fetchFailed
    case postFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .fetchFailed: return "Failed to fetch data from server"
        case .postFailed: return "Failed to post data to server"
        case .deleteFailed: return "Failed to delete data from server"
        }
    }
}
