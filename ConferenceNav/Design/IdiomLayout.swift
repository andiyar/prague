import SwiftUI
import UIKit

enum CNLayout {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    enum MaxWidth {
        static let readerBody: CGFloat = 600
        static let noteEditor: CGFloat = 640
        static let tabContent: CGFloat = 720
    }

    enum Spacing {
        static var screenHorizontal: CGFloat { isPad ? 28 : 16 }
        static var sectionVertical: CGFloat { isPad ? 24 : 16 }
        static var cardPadding: CGFloat { isPad ? 18 : 12 }
    }
}

extension View {
    /// Centres content with a max-width on iPad; full-bleed on iPhone.
    func cnPadMaxWidth(_ width: CGFloat) -> some View {
        self
            .frame(maxWidth: CNLayout.isPad ? width : .infinity)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
