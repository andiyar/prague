import SwiftUI

// MARK: - Colour Palette

struct CNColors {
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "0D0D1A") : Color(hex: "FAFAF7")
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1A1A2E") : .white
    }

    static func surfaceSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "141425") : Color(hex: "F5F3EE")
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FAFAF7") : Color(hex: "22272B")
    }

    static let textSecondary = Color(hex: "8C8C8C")

    static func navy(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "4A7FD4") : Color(hex: "002664")
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FF4D6A") : Color(hex: "D7153A")
    }

    static func gold(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "E0B840") : Color(hex: "C9A227")
    }

    static func teal(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "3DBAD4") : Color(hex: "1B6B7D")
    }

    static func conflictAmber(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FFB340") : Color(hex: "E6940A")
    }

    static func typeBadgeColor(for type: SessionType, scheme: ColorScheme) -> Color {
        switch type {
        case .keynote: return red(for: scheme)
        case .oral: return navy(for: scheme)
        case .panel: return teal(for: scheme)
        case .poster: return gold(for: scheme)
        case .general: return textSecondary
        case .meeting: return Color(hex: "BBBBBB")
        case .social: return teal(for: scheme)
        case .tea, .lunch: return textSecondary
        }
    }
}

// MARK: - Typography

struct CNFonts {
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let largeTitle = serif(28)
    static let title = serif(22)
    static let title2 = serif(18)
    static let headline = sans(16, weight: .semibold)
    static let body = sans(15)
    static let caption = sans(13)
    static let small = sans(11)
    static let time = mono(13, weight: .semibold)
    static let timeSmall = mono(11)

    // iPad-tuned variants — fall back to phone tokens on iPhone
    static var readerHeadline: Font {
        CNLayout.isPad
            ? .custom("New York", size: 32).weight(.medium)
            : title
    }
    static var readerBody: Font {
        CNLayout.isPad
            ? .custom("New York", size: 18)
            : body
    }
    static var readerCaption: Font {
        CNLayout.isPad
            ? .custom("New York", size: 13).italic()
            : caption.italic()
    }
    static var readerMeta: Font {
        .system(size: CNLayout.isPad ? 11 : 10, weight: .regular, design: .default)
    }
}

// MARK: - Card Style

struct CNCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var typeColor: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(CNColors.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .leading) {
                if typeColor != .clear {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(typeColor)
                        .frame(width: 4)
                        .padding(.vertical, 6)
                }
            }
            .shadow(
                color: colorScheme == .dark
                    ? .clear
                    : .black.opacity(0.06),
                radius: 4, x: 0, y: 2
            )
    }
}

extension View {
    func cnCard(typeColor: Color = .clear) -> some View {
        modifier(CNCardStyle(typeColor: typeColor))
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
