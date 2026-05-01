import SwiftUI
import PencilKit

enum SketchToolKind: Hashable {
    case pen, pencil, marker, eraser

    var inkType: PKInkingTool.InkType? {
        switch self {
        case .pen: return .pen
        case .pencil: return .pencil
        case .marker: return .marker
        case .eraser: return nil
        }
    }

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .eraser: return "eraser.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .pen: return "Pen"
        case .pencil: return "Pencil"
        case .marker: return "Marker"
        case .eraser: return "Eraser"
        }
    }
}

struct SketchToolbar: View {
    @Binding var selectedTool: SketchToolKind
    @Binding var selectedColor: Color
    let onUndo: () -> Void
    let onRedo: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var showingColorPalette = false

    private let palette: [Color] = [
        Color(red: 0.0, green: 0.15, blue: 0.39),    // navy
        Color(red: 0.85, green: 0.08, blue: 0.23),   // red
        Color(red: 0.79, green: 0.64, blue: 0.16),   // gold
        Color(red: 0.11, green: 0.42, blue: 0.49),   // teal
        Color.black,
        Color(red: 0.4, green: 0.4, blue: 0.4),      // grey
        Color(red: 0.45, green: 0.10, blue: 0.55),   // purple
        Color(red: 0.2, green: 0.55, blue: 0.2),     // green
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach([SketchToolKind.pen, .pencil, .marker, .eraser], id: \.self) { kind in
                toolButton(kind: kind)
            }

            Button { showingColorPalette = true } label: {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .padding(6)
            }
            .accessibilityLabel("Colour picker")
            .popover(isPresented: $showingColorPalette) {
                paletteView()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            .accessibilityLabel("Undo")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            .accessibilityLabel("Redo")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.0, green: 0.10, blue: 0.27))
    }

    private func colorName(_ color: Color) -> String {
        if color == palette[0] { return "Navy" }
        if color == palette[1] { return "Red" }
        if color == palette[2] { return "Gold" }
        if color == palette[3] { return "Teal" }
        if color == palette[4] { return "Black" }
        if color == palette[5] { return "Grey" }
        if color == palette[6] { return "Purple" }
        if color == palette[7] { return "Green" }
        return "Custom colour"
    }

    @ViewBuilder
    private func toolButton(kind: SketchToolKind) -> some View {
        let isActive = selectedTool == kind
        Button { selectedTool = kind } label: {
            Image(systemName: kind.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? Color(red: 0.0, green: 0.15, blue: 0.39) : .white)
                .frame(width: 36, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color(red: 0.79, green: 0.64, blue: 0.16) : Color.white.opacity(0.08))
                )
        }
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func paletteView() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 4), spacing: 8) {
            ForEach(palette, id: \.self) { color in
                Button {
                    selectedColor = color
                    showingColorPalette = false
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .accessibilityLabel(colorName(color))
            }
        }
        .padding(12)
    }
}

#Preview {
    @Previewable @State var tool: SketchToolKind = .pen
    @Previewable @State var color: Color = Color(red: 0.0, green: 0.15, blue: 0.39)
    return SketchToolbar(
        selectedTool: $tool,
        selectedColor: $color,
        onUndo: {},
        onRedo: {}
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
