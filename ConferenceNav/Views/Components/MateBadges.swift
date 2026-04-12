import SwiftUI

struct MateBadges: View {
    let session: Session
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            if store.isPicked(session.id) {
                badge(store.currentUser.badge, color: CNColors.navy(for: colorScheme))
            }
            if store.isMatePicked(session.id) {
                badge(store.currentUser.mate.badge, color: CNColors.red(for: colorScheme))
            }
        }
    }

    private func badge(_ letter: String, color: Color) -> some View {
        Text(letter)
            .font(CNFonts.sans(10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
