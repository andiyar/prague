import SwiftUI

struct SplashScreen: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            CNColors.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // App identity
                VStack(spacing: 8) {
                    Text("EAPC 2026")
                        .font(CNFonts.sans(12, weight: .semibold))
                        .foregroundStyle(CNColors.textSecondary)
                        .tracking(4)

                    Text("EAPragueC")
                        .font(CNFonts.serif(42))
                        .foregroundStyle(CNColors.navy(for: colorScheme))

                    Text("2026")
                        .font(CNFonts.serif(28, weight: .regular))
                        .foregroundStyle(CNColors.gold(for: colorScheme))
                }

                // Divider accent
                RoundedRectangle(cornerRadius: 1)
                    .fill(CNColors.gold(for: colorScheme))
                    .frame(width: 40, height: 2)

                Text("Your Conference Czechlist")
                    .font(CNFonts.sans(16, weight: .medium))
                    .foregroundStyle(CNColors.teal(for: colorScheme))
                    .italic()

                Spacer()

                // Footer
                VStack(spacing: 4) {
                    Text("20th World Congress")
                        .font(CNFonts.sans(11))
                    Text("European Association for Palliative Care")
                        .font(CNFonts.sans(11))
                    Text("Prague · May 14-16")
                        .font(CNFonts.sans(11, weight: .medium))
                }
                .foregroundStyle(CNColors.textSecondary)
                .padding(.bottom, 48)
            }
        }
    }
}
