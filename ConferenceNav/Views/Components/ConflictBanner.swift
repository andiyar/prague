import SwiftUI

struct ConflictBanner: View {
    let conflictingTitle: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text("Conflicts with \(conflictingTitle)")
                .font(CNFonts.small)
                .lineLimit(1)
        }
        .foregroundStyle(CNColors.conflictAmber(for: colorScheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CNColors.conflictAmber(for: colorScheme).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
