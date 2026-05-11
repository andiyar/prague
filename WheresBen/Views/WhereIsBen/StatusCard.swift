import SwiftUI

struct StatusCard: View {
    @EnvironmentObject var tripData: TripDataService
    @State private var isAnimating = false
    @State private var showPhotoFullscreen = false

    private var showPhoto: Bool {
        tripData.currentStatus.photoUrl != nil && tripData.currentStatus.audience.showsOnMain
    }

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

            if showPhoto, let urlString = tripData.currentStatus.photoUrl, let url = URL(string: urlString) {
                photoView(url: url)
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
        .fullScreenCover(isPresented: $showPhotoFullscreen) {
            if let urlString = tripData.currentStatus.photoUrl, let url = URL(string: urlString) {
                FullscreenPhotoView(url: url) {
                    showPhotoFullscreen = false
                }
            }
        }
    }

    @ViewBuilder
    private func photoView(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color.cozyCardBackground.overlay(
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundColor(.cozyTextSecondary)
                )
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { showPhotoFullscreen = true }
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

struct FullscreenPhotoView: View {
    let url: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.6))
                case .empty:
                    ProgressView().tint(.white)
                @unknown default:
                    EmptyView()
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, .black.opacity(0.4))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .statusBarHidden()
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
