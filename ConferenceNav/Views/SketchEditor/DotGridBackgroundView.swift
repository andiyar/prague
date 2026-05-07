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
        // Editor background is fixed cream regardless of system theme, so the
        // dot colour is also fixed. Original `0.90` on `0.98` cream was nearly
        // invisible on iPad mini at typical brightness; `0.78` is just-visible
        // and stays subtle enough not to compete with strokes.
        let dotColor = UIColor(red: 0.78, green: 0.78, blue: 0.75, alpha: 1.0)
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
