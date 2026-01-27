import Foundation
import Combine

/// Main service for managing trip data - used by Where's Ben? app
@MainActor
class TripDataService: ObservableObject {
    static let shared = TripDataService()

    @Published var segments: [TripSegment] = []
    @Published var config: TripConfig = TripConfig(from: [])
    @Published var currentStatus: CurrentStatus = .preTrip
    @Published var isLoading = true
    @Published var error: Error?

    // Debug mode - allows time travel through the trip
    @Published var debugTimeOffset: TimeInterval = 0
    @Published var isDebugMode = false

    var effectiveNow: Date {
        Date().addingTimeInterval(debugTimeOffset)
    }

    private var refreshTask: Task<Void, Never>?

    private init() {}

    // MARK: - Data Loading

    func loadAllData() async {
        isLoading = true
        error = nil

        do {
            async let segmentsTask = SupabaseClient.shared.fetchTripSegments()
            async let configTask = SupabaseClient.shared.fetchConfig()

            segments = try await segmentsTask
            config = try await configTask

            updateCurrentStatus()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func refresh() async {
        do {
            if let override = try await SupabaseClient.shared.fetchActiveOverride() {
                currentStatus = CurrentStatus(from: override)
            } else {
                updateCurrentStatus()
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Status Calculation

    func updateCurrentStatus() {
        let now = effectiveNow

        // Find current segment based on time
        if let segment = segments.first(where: { now >= $0.startTime && now < $0.endTime }) {
            currentStatus = CurrentStatus(from: segment)
        } else if let firstSegment = segments.first, now < firstSegment.startTime {
            currentStatus = .preTrip
        } else {
            currentStatus = .postTrip
        }
    }

    // MARK: - Debug Mode

    func setDebugTime(_ date: Date) {
        debugTimeOffset = date.timeIntervalSince(Date())
        updateCurrentStatus()
    }

    func resetDebugTime() {
        debugTimeOffset = 0
        updateCurrentStatus()
    }

    // MARK: - Flight Helpers

    var flights: [TripSegment] {
        segments.filter { $0.isFlying }
    }

    var outboundFlights: [TripSegment] {
        flights.filter { $0.flightTo == "DXB" || $0.flightTo == "PRG" }
    }

    var returnFlights: [TripSegment] {
        flights.filter { $0.flightTo == "DXB" && $0.flightFrom == "PRG" || $0.flightTo == "SYD" }
    }

    func flightStatus(for segment: TripSegment) -> FlightStatus {
        let now = effectiveNow
        if now < segment.startTime {
            return .upcoming
        } else if now < segment.endTime {
            let progress = (now.timeIntervalSince(segment.startTime)) / (segment.endTime.timeIntervalSince(segment.startTime))
            return .inProgress(progress: progress)
        } else {
            return .complete
        }
    }

    // MARK: - Countdown Helpers

    var timeUntilHome: TimeInterval? {
        guard let returnTime = config.returnDateTimeUTC else { return nil }
        let diff = returnTime.timeIntervalSince(effectiveNow)
        return diff > 0 ? diff : nil
    }

    var sleepsUntilHome: Int {
        guard let returnTime = config.returnDateTimeUTC else { return 0 }

        let sydney = TimeZone(identifier: "Australia/Sydney")!
        var calendar = Calendar.current
        calendar.timeZone = sydney

        let now = effectiveNow
        var sleeps = 0
        var checkDate = calendar.startOfDay(for: now)
        checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!

        while checkDate <= returnTime {
            sleeps += 1
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }

        return sleeps
    }

    // MARK: - Automatic Refresh

    func startAutoRefresh() {
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

enum FlightStatus {
    case upcoming
    case inProgress(progress: Double)
    case complete

    var isActive: Bool {
        if case .inProgress = self { return true }
        return false
    }
}
