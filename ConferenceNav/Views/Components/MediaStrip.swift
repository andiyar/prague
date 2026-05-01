import SwiftUI

struct MediaStrip: View {
    let photoFilenames: [String]
    let sketchFilenames: [String]
    let onAddSketch: () -> Void
    let onAddPhoto: () -> Void
    let onTapMedia: (MediaItem) -> Void

    enum MediaItem: Hashable {
        case photo(filename: String)
        case sketch(filename: String)

        var filename: String {
            switch self {
            case .photo(let f), .sketch(let f): return f
            }
        }
    }

    @Environment(NotesStore.self) var notesStore

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAddSketch) {
                Label("Sketch", systemImage: "scribble.variable")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0, green: 0.15, blue: 0.39))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!CNLayout.isPad)
            .opacity(CNLayout.isPad ? 1 : 0.4)

            Button(action: onAddPhoto) {
                Label("Photo", systemImage: "photo")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.11, green: 0.42, blue: 0.49))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sketchFilenames, id: \.self) { f in
                        thumbnail(for: .sketch(filename: f))
                    }
                    ForEach(photoFilenames, id: \.self) { f in
                        thumbnail(for: .photo(filename: f))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    @ViewBuilder
    private func thumbnail(for item: MediaItem) -> some View {
        Button { onTapMedia(item) } label: {
            ZStack {
                if let url = thumbnailURL(for: item),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: item.iconName)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func thumbnailURL(for item: MediaItem) -> URL? {
        switch item {
        case .photo(let f): return notesStore.photoURL(filename: f)
        case .sketch(let f): return notesStore.sketchURL(filename: f)
        }
    }
}

private extension MediaStrip.MediaItem {
    var iconName: String {
        switch self {
        case .photo: return "photo"
        case .sketch: return "scribble.variable"
        }
    }
}
