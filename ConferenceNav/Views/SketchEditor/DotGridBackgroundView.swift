import SwiftUI
import UIKit

struct DotGridBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> DotGridUIView { DotGridUIView() }
    func updateUIView(_ uiView: DotGridUIView, context: Context) { uiView.setNeedsDisplay() }
}

final class DotGridUIView: UIView {
    private let spacing: CGFloat = 24
    private let dotRadius: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let isDark = traitCollection.userInterfaceStyle == .dark
        let dotColor = isDark ? UIColor(white: 1.0, alpha: 0.16) : UIColor(red: 0.90, green: 0.90, blue: 0.88, alpha: 1.0)
        ctx.setFillColor(dotColor.cgColor)

        var y: CGFloat = spacing / 2
        while y < rect.height {
            var x: CGFloat = spacing / 2
            while x < rect.width {
                let dot = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                ctx.fillEllipse(in: dot)
                x += spacing
            }
            y += spacing
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }
}

#Preview {
    DotGridBackground()
        .frame(width: 400, height: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
}
