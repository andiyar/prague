import SwiftUI

struct QuickStatusGrid: View {
    let onStatusSelected: (QuickStatus) -> Void
    let onCustomSelected: () -> Void
    let isEnabled: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(QuickStatus.options) { status in
                QuickStatusButton(
                    status: status,
                    isEnabled: isEnabled
                ) {
                    onStatusSelected(status)
                }
            }

            // Custom message button
            CustomMessageButton(isEnabled: isEnabled) {
                onCustomSelected()
            }
        }
    }
}

struct QuickStatusButton: View {
    let status: QuickStatus
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(status.emoji)
                    .font(.system(size: 36))

                Text(status.label)
                    .font(.cozyCaption)
                    .foregroundColor(.cozyText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.cozyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .pressEvents {
            withAnimation(.bouncy) { isPressed = true }
        } onRelease: {
            withAnimation(.bouncy) { isPressed = false }
        }
    }
}

struct CustomMessageButton: View {
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("💬")
                    .font(.system(size: 36))

                Text("Custom...")
                    .font(.cozyCaption)
                    .foregroundColor(.cozyAccent)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.cozyAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cozyAccent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .pressEvents {
            withAnimation(.bouncy) { isPressed = true }
        } onRelease: {
            withAnimation(.bouncy) { isPressed = false }
        }
    }
}

// MARK: - Press Events Modifier

struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

#Preview {
    ZStack {
        Color.cozyBackground.ignoresSafeArea()

        QuickStatusGrid(
            onStatusSelected: { status in
                print("Selected: \(status.label)")
            },
            onCustomSelected: {
                print("Custom selected")
            },
            isEnabled: true
        )
        .padding()
    }
}
