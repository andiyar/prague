import Foundation

struct UserProfile: Equatable {
    let id: String
    let displayName: String
    let badge: String

    static let ben = UserProfile(id: "ben", displayName: "Ben", badge: "B")
    static let ron = UserProfile(id: "ron", displayName: "Ron", badge: "R")

    var mate: UserProfile {
        self == .ben ? .ron : .ben
    }
}
