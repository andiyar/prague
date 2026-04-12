import SwiftUI

struct DayPicker: View {
    @Binding var selectedDate: String
    @Environment(\.colorScheme) var colorScheme

    private let days: [(date: String, short: String, label: String)] = [
        ("2026-05-14", "THU", "14 May"),
        ("2026-05-15", "FRI", "15 May"),
        ("2026-05-16", "SAT", "16 May"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.date) { day in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = day.date
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(day.short)
                            .font(CNFonts.sans(13, weight: .bold))
                        Text(day.label)
                            .font(CNFonts.sans(10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedDate == day.date
                            ? CNColors.navy(for: colorScheme)
                            : CNColors.surfaceSecondary(for: colorScheme)
                    )
                    .foregroundStyle(
                        selectedDate == day.date
                            ? .white
                            : CNColors.textPrimary(for: colorScheme)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }
}
