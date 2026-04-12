import SwiftUI

struct TypeBadge: View {
    let type: SessionType
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(type.rawValue)
            .font(CNFonts.sans(10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(CNColors.typeBadgeColor(for: type, scheme: colorScheme).opacity(0.15))
            .foregroundStyle(CNColors.typeBadgeColor(for: type, scheme: colorScheme))
            .clipShape(Capsule())
    }
}
