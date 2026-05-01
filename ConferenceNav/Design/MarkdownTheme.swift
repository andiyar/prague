import MarkdownUI
import SwiftUI
import UIKit

/// Resolves relative image paths in note bodies (e.g. `sketches/abc.png`,
/// `photos/xyz.jpg`) to local files in the iCloud Drive notes container.
/// Without this, MarkdownUI's default provider sends relative URLs through
/// URLSession and they fail to load — sketches would render as empty space
/// in the in-app Preview.
struct LocalMediaImageProvider: ImageProvider {
    let notesStore: NotesStore

    @ViewBuilder
    func makeImage(url: URL?) -> some View {
        if let url, let local = localFileURL(for: url),
           let data = try? Data(contentsOf: local),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else {
            EmptyView()
        }
    }

    private func localFileURL(for url: URL) -> URL? {
        let raw = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        if raw.hasPrefix("sketches/") {
            return notesStore.sketchURL(filename: String(raw.dropFirst("sketches/".count)))
        }
        if raw.hasPrefix("photos/") {
            return notesStore.photoURL(filename: String(raw.dropFirst("photos/".count)))
        }
        return nil
    }
}

extension Theme {
    /// Conference-themed Markdown rendering
    static func conference(colorScheme: ColorScheme) -> Theme {
        .gitHub
            .text {
                ForegroundColor(CNColors.textPrimary(for: colorScheme))
                if CNLayout.isPad {
                    FontFamily(.custom("New York"))
                    FontSize(18)
                } else {
                    FontSize(15)
                }
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                ForegroundColor(CNColors.teal(for: colorScheme))
            }
            .link {
                ForegroundColor(CNColors.teal(for: colorScheme))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(22)
                        ForegroundColor(CNColors.navy(for: colorScheme))
                    }
                    .markdownMargin(top: 16, bottom: 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(18)
                        ForegroundColor(CNColors.navy(for: colorScheme))
                    }
                    .markdownMargin(top: 12, bottom: 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(16)
                        ForegroundColor(CNColors.textPrimary(for: colorScheme))
                    }
                    .markdownMargin(top: 10, bottom: 4)
            }
            .blockquote { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontStyle(.italic)
                        ForegroundColor(CNColors.textSecondary)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(CNColors.teal(for: colorScheme).opacity(0.4))
                            .frame(width: 3)
                    }
                    .markdownMargin(top: 8, bottom: 8)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(12)
                    .background(CNColors.surfaceSecondary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .markdownMargin(top: 8, bottom: 8)
            }
    }
}
