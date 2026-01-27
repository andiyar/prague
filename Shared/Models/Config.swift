import Foundation

struct ConfigRow: Codable {
    let key: String
    let value: String?
}

struct TripConfig {
    var dadName: String = "Ben"
    var homeTimezone: String = "Australia/Sydney"
    var tripTimezone: String = "Europe/Prague"
    var returnDateTimeUTC: Date?
    var contactPhone: String?
    var emergencyContact: String?
    var hotelName: String?
    var hotelAddress: String?
    var hotelPhone: String?
    var conferenceName: String?
    var conferenceURL: String?
    var consulatePhone: String?
    var insurancePhone: String?
    var insurancePolicy: String?

    init(from rows: [ConfigRow]) {
        for row in rows {
            switch row.key {
            case "dad_name":
                dadName = row.value ?? "Ben"
            case "home_timezone":
                homeTimezone = row.value ?? "Australia/Sydney"
            case "trip_timezone":
                tripTimezone = row.value ?? "Europe/Prague"
            case "return_datetime_utc":
                if let value = row.value {
                    returnDateTimeUTC = ISO8601DateFormatter().date(from: value)
                }
            case "contact_phone":
                contactPhone = row.value
            case "emergency_contact":
                emergencyContact = row.value
            case "hotel_name":
                hotelName = row.value
            case "hotel_address":
                hotelAddress = row.value
            case "hotel_phone":
                hotelPhone = row.value
            case "conference_name":
                conferenceName = row.value
            case "conference_url":
                conferenceURL = row.value
            case "consulate_phone":
                consulatePhone = row.value
            case "insurance_phone":
                insurancePhone = row.value
            case "insurance_policy":
                insurancePolicy = row.value
            default:
                break
            }
        }
    }
}
