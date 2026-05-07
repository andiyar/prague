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
        if let url, let local = localFileURL(for: url) {
            AsyncLocalImage(url: local)
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

/// Loads a local image off the main thread and caches the result. Replaces
/// the synchronous `Data(contentsOf:)` + `UIImage(data:)` we used to do in
/// the ImageProvider — that approach blocked the main thread on
/// iCloud-backed files that hadn't downloaded yet, and re-loaded on every
/// re-render. With this view, the load happens in a detached task and
/// re-renders hit the in-memory cache.
struct AsyncLocalImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Subtle placeholder while the image loads — keeps layout stable.
                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: url) {
            self.image = await Self.loadImage(at: url)
        }
    }

    private static func loadImage(at url: URL) async -> UIImage? {
        if let cached = LocalImageCache.shared.image(for: url) { return cached }
        let loaded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return nil }
            return image
        }.value
        if let loaded { LocalImageCache.shared.set(loaded, for: url) }
        return loaded
    }
}

/// Process-wide in-memory cache for note media images. NSCache evicts under
/// memory pressure automatically; we cap count at 50 so a long scroll
/// through many notes doesn't balloon RAM forever.
final class LocalImageCache {
    static let shared = LocalImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private init() { cache.countLimit = 50 }
    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func set(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
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
