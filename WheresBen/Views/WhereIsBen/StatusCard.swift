import SwiftUI

struct StatusCard: View {
    @EnvironmentObject var tripData: TripDataService
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Emoji with glow
                Text(tripData.currentStatus.emoji)
                    .font(.system(size: 56))
                    .glow(color: .cozyAccent, radius: 15)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(tripData.currentStatus.text)
                        .font(.cozyTitle2)
                        .foregroundColor(.cozyText)

                    if let note = tripData.currentStatus.note {
                        Text(note)
                            .font(.cozyBody)
                            .foregroundColor(.cozyTextSecondary)
                    }
                }

                Spacer()
            }

            // Updated timestamp
            if tripData.currentStatus.isOverride, let updatedAt = tripData.currentStatus.updatedAt {
                HStack {
                    Spacer()
                    Text("Updated \(timeAgo(from: updatedAt))")
                        .font(.cozyCaption)
                        .foregroundColor(.cozyTextSecondary)
                        .italic()
                }
            }
        }
        .padding()
        .cozyCard(highlighted: tripData.currentStatus.isOverride)
        .onAppear {
            isAnimating = true
        }
    }

    private func timeAgo(from date: Date) -> String {
        let diff = Int(tripData.effectiveNow.timeIntervalSince(date) / 60)

        if diff < 1 { return "just now" }
        if diff < 60 { return "\(diff) minute\(diff == 1 ? "" : "s") ago" }
        if diff < 1440 {
            let hours = diff / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        let days = diff / 1440
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

#Preview {
    ZStack {
        Color.cozyBackground.ignoresSafeArea()
        StatusCard()
            .padding()
    }
    .environmentObject(TripDataService.shared)
}
