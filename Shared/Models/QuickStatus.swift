import Foundation

/// Pre-defined status options for Captain's Log
struct QuickStatus: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let statusText: String
    let kidsText: String

    static let options: [QuickStatus] = [
        QuickStatus(
            emoji: "✈️",
            label: "Taking off",
            statusText: "Taking off",
            kidsText: "Daddy's on the plane!"
        ),
        QuickStatus(
            emoji: "🛬",
            label: "Just landed",
            statusText: "Just landed",
            kidsText: "Daddy just landed!"
        ),
        QuickStatus(
            emoji: "🏨",
            label: "At hotel",
            statusText: "At the hotel",
            kidsText: "Daddy's at the hotel"
        ),
        QuickStatus(
            emoji: "📍",
            label: "At conference",
            statusText: "At the conference",
            kidsText: "Daddy's at the conference"
        ),
        QuickStatus(
            emoji: "🍽️",
            label: "Getting food",
            statusText: "Getting food",
            kidsText: "Daddy's having dinner"
        ),
        QuickStatus(
            emoji: "😴",
            label: "Going to sleep",
            statusText: "Going to sleep",
            kidsText: "Daddy's sleeping"
        ),
        QuickStatus(
            emoji: "☕",
            label: "Awake now",
            statusText: "Good morning!",
            kidsText: "Daddy's awake!"
        ),
        QuickStatus(
            emoji: "🏠",
            label: "Heading home",
            statusText: "Heading home!",
            kidsText: "Daddy's coming home!"
        )
    ]
}
