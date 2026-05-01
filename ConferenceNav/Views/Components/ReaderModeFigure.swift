import SwiftUI

struct ReaderModeFigure: View {
    let imageURL: URL?
    let caption: String?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let url = imageURL,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 480)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(Image(systemName: "photo"))
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(CNFonts.readerCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
}
