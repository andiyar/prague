import SwiftUI

struct StatusCard: View {
    @EnvironmentObject var tripData: TripDataService
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Status image with emoji fallback
                statusImage
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

            // Updated timestamp (only show if recent - within 1 hour)
            if tripData.currentStatus.isOverride,
               let updatedAt = tripData.currentStatus.updatedAt,
               Date().timeIntervalSince(updatedAt) < 3600 {
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

    // MARK: - Status Image

    @ViewBuilder
    private var statusImage: some View {
        if let imageName = statusImageName, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
        } else {
            // Emoji fallback
            Text(tripData.currentStatus.emoji)
                .font(.system(size: 56))
                .glow(color: .cozyAccent, radius: 15)
        }
    }

    private var statusImageName: String? {
        let emoji = tripData.currentStatus.emoji
        switch emoji {
        case "📅": return "status-pretrip"
        case "✈️": return "status-flying"
        case "🛬": return "status-landing"
        case "⏳": return "status-layover"
        case "🏨": return "status-hotel"
        case "📍": return "status-conference"
        case "😴": return "status-sleeping"
        case "🏠": return "status-home"
        default: return nil
        }
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
