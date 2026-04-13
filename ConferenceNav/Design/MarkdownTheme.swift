import MarkdownUI
import SwiftUI

extension Theme {
    /// Conference-themed Markdown rendering
    static func conference(colorScheme: ColorScheme) -> Theme {
        .gitHub
            .text {
                ForegroundColor(CNColors.textPrimary(for: colorScheme))
                FontSize(15)
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
