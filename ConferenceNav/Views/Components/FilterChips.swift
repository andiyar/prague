import SwiftUI

struct FilterChips<T: Hashable>: View {
    let label: String
    let options: [T]
    @Binding var selected: Set<T>
    let title: (T) -> String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(label)
                    .font(CNFonts.sans(11, weight: .medium))
                    .foregroundStyle(CNColors.textSecondary)

                ForEach(Array(options), id: \.self) { option in
                    Button {
                        if selected.contains(option) {
                            selected.remove(option)
                        } else {
                            selected.insert(option)
                        }
                    } label: {
                        Text(title(option))
                            .font(CNFonts.sans(12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selected.contains(option)
                                    ? CNColors.navy(for: colorScheme)
                                    : CNColors.surfaceSecondary(for: colorScheme)
                            )
                            .foregroundStyle(
                                selected.contains(option)
                                    ? .white
                                    : CNColors.textPrimary(for: colorScheme)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
