import SwiftUI

// MARK: - Colors

extension Color {
    // Family View - Cozy palette
    static let cozyBackground = Color(hex: "FAF7F2")
    static let cozyAccent = Color(hex: "C4846C")      // Terracotta
    static let cozySage = Color(hex: "8FA98F")        // Sage green (success/home)
    static let cozyText = Color(hex: "3D3D3D")        // Warm charcoal
    static let cozyTextSecondary = Color(hex: "6B6B6B")
    static let cozyCardBackground = Color.white
    static let cozyCardBorder = Color(hex: "E8E4DE")

    // Kids View - Playful palette
    static let kidsSkyTop = Color(hex: "87CEEB")
    static let kidsSkyBottom = Color(hex: "FFE4C4")   // Bisque/peachy
    static let kidsCloud = Color.white
    static let kidsSun = Color(hex: "FFD93D")
    static let kidsPurple = Color(hex: "9B5DE5")
    static let kidsPink = Color(hex: "F15BB5")

    // Utility
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
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

// MARK: - Typography

extension Font {
    static let cozyLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let cozyTitle = Font.system(.title, design: .rounded, weight: .semibold)
    static let cozyTitle2 = Font.system(.title2, design: .rounded, weight: .medium)
    static let cozyTitle3 = Font.system(.title3, design: .rounded, weight: .medium)
    static let cozyHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let cozyBody = Font.system(.body, design: .rounded)
    static let cozyCaption = Font.system(.caption, design: .rounded)

    static let kidsGiant = Font.system(size: 72, weight: .bold, design: .rounded)
    static let kidsLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let kidsTitle = Font.system(size: 32, weight: .bold, design: .rounded)
    static let kidsBody = Font.system(size: 20, weight: .semibold, design: .rounded)
}

// MARK: - Card Styling

struct CozyCardStyle: ViewModifier {
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cozyCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isHighlighted ? Color.cozyAccent : Color.cozyCardBorder, lineWidth: isHighlighted ? 2 : 1)
            )
    }
}

extension View {
    func cozyCard(highlighted: Bool = false) -> some View {
        modifier(CozyCardStyle(isHighlighted: highlighted))
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 1.5)
    }
}

extension View {
    func glow(color: Color = .cozyAccent, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Kids View Background

struct KidsSkyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.kidsSkyTop, .kidsSkyBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Animated Clouds

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Main ellipse
        path.addEllipse(in: CGRect(x: width * 0.2, y: height * 0.4, width: width * 0.6, height: height * 0.5))
        // Left bump
        path.addEllipse(in: CGRect(x: 0, y: height * 0.5, width: width * 0.4, height: height * 0.4))
        // Right bump
        path.addEllipse(in: CGRect(x: width * 0.6, y: height * 0.45, width: width * 0.4, height: height * 0.45))
        // Top bump
        path.addEllipse(in: CGRect(x: width * 0.3, y: height * 0.1, width: width * 0.4, height: height * 0.5))

        return path
    }
}

struct FloatingCloud: View {
    let size: CGFloat
    let duration: Double
    let delay: Double

    @State private var offset: CGFloat = -200

    var body: some View {
        CloudShape()
            .fill(Color.kidsCloud.opacity(0.9))
            .frame(width: size, height: size * 0.6)
            .offset(x: offset)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    offset = UIScreen.main.bounds.width + 200
                }
            }
    }
}

// MARK: - Bouncy Animation

extension Animation {
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    static let gentleBounce = Animation.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)
}

// MARK: - Preview Helpers

#Preview("Color Palette") {
    VStack(spacing: 20) {
        HStack {
            Rectangle().fill(Color.cozyBackground)
            Rectangle().fill(Color.cozyAccent)
            Rectangle().fill(Color.cozySage)
            Rectangle().fill(Color.cozyText)
        }
        .frame(height: 50)

        HStack {
            Rectangle().fill(Color.kidsSkyTop)
            Rectangle().fill(Color.kidsSkyBottom)
            Rectangle().fill(Color.kidsPurple)
            Rectangle().fill(Color.kidsPink)
        }
        .frame(height: 50)
    }
    .padding()
}
