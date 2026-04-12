import SwiftUI

struct PickButton: View {
    let sessionId: Int
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme
    @State private var animating = false

    var isPicked: Bool { store.isPicked(sessionId) }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                animating = true
            }
            store.togglePick(sessionId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animating = false
            }
        } label: {
            Image(systemName: isPicked ? "star.fill" : "star")
                .font(.system(size: 20))
                .foregroundStyle(
                    isPicked
                        ? CNColors.gold(for: colorScheme)
                        : CNColors.textSecondary
                )
                .scaleEffect(animating ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
