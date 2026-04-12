import SwiftUI

struct UserPickerView: View {
    @Environment(ConferenceStore.self) var store
    @Environment(\.colorScheme) var colorScheme
    var onSelect: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("EAPC 2026")
                    .font(CNFonts.sans(14, weight: .semibold))
                    .foregroundStyle(CNColors.textSecondary)
                    .tracking(3)
                Text("Conference\nNavigator")
                    .font(CNFonts.serif(36))
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            Text("Who are you?")
                .font(CNFonts.title2)
                .foregroundStyle(CNColors.textSecondary)

            HStack(spacing: 20) {
                userButton(.ben)
                userButton(.ron)
            }

            Spacer()

            Text("Programme data as of \(store.lastUpdated)")
                .font(CNFonts.small)
                .foregroundStyle(CNColors.textSecondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(CNColors.background(for: colorScheme))
    }

    private func userButton(_ user: UserProfile) -> some View {
        Button {
            store.switchUser(to: user)
            UserDefaults.standard.set(user.id, forKey: "conferenceNavUser")
            onSelect()
        } label: {
            VStack(spacing: 8) {
                Text(user.badge)
                    .font(CNFonts.serif(32))
                    .frame(width: 72, height: 72)
                    .background(CNColors.navy(for: colorScheme))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                Text(user.displayName)
                    .font(CNFonts.headline)
                    .foregroundStyle(CNColors.textPrimary(for: colorScheme))
            }
        }
    }
}
