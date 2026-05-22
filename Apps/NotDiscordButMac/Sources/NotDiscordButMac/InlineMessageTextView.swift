import DiscordKit
import SwiftUI

struct InlineMessageTextView: View {
    let block: MessageTextBlock
    let fontSize: Double

    var body: some View {
        switch block.paragraphStyle {
        case .normal:
            renderedContent

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•")
                    .font(.system(size: fontSize + 1, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)

                renderedContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        if block.fragments.count == 1, case let .text(fragment) = block.fragments[0] {
            Text(fragment.content)
                .font(.system(size: fontSize, weight: .regular, design: .default))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            InlineFragmentFlowLayout(spacing: 0, lineSpacing: max(fontSize * 0.16, 2)) {
                ForEach(flowFragments) { fragment in
                    InlineMessageFragmentView(
                        fragment: fragment,
                        fontSize: fontSize
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var flowFragments: [MessageInlineFragment] {
        block.fragments.flatMap { fragment in
            switch fragment {
            case let .text(textFragment):
                splitFlowTextFragment(textFragment)
            case .customEmoji:
                [fragment]
            }
        }
    }

    private func splitFlowTextFragment(_ fragment: MessageTextFragment) -> [MessageInlineFragment] {
        let source = String(fragment.content.characters)
        guard !source.isEmpty else {
            return []
        }

        let tokens = source.splitIntoInlineFlowTokens()
        guard tokens.count > 1 else {
            return [.text(fragment)]
        }

        return tokens.enumerated().map { index, token in
            .text(
                MessageTextFragment(
                    id: "\(fragment.id)-token-\(index)",
                    content: AttributedString(token)
                )
            )
        }
    }
}

private struct InlineMessageFragmentView: View {
    let fragment: MessageInlineFragment
    let fontSize: Double

    var body: some View {
        switch fragment {
        case let .text(textFragment):
            Text(textFragment.content)
                .font(.system(size: fontSize, weight: .regular, design: .default))
                .foregroundStyle(.primary)
                .fixedSize()

        case let .customEmoji(emoji):
            InlineCustomEmojiView(
                emoji: emoji,
                size: max(fontSize * 1.22, 18)
            )
        }
    }
}

private struct InlineCustomEmojiView: View {
    let emoji: MessageCustomEmojiFragment
    let size: Double

    var body: some View {
        RemoteAssetView(
            url: emoji.imageURL,
            kind: .customEmoji,
            animationPolicy: .always,
            scalingMode: .fit,
            showsBackground: false,
            isAnimating: true
        ) {
            Text(emoji.fallbackText)
                .font(.system(size: size * 0.52, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .opacity(0.45)
        }
        .frame(width: size, height: size)
        .alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.bottom] - (size * 0.22)
        }
        .accessibilityLabel(emoji.fallbackText)
    }
}

private struct InlineFragmentFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    init(spacing: CGFloat, lineSpacing: CGFloat) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var size = CGSize.zero

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if origin.x > 0, origin.x + subviewSize.width > maxWidth {
                origin.x = 0
                origin.y += lineHeight + lineSpacing
                lineHeight = 0
            }

            lineHeight = max(lineHeight, subviewSize.height)
            size.width = max(size.width, origin.x + subviewSize.width)
            size.height = max(size.height, origin.y + subviewSize.height)
            origin.x += subviewSize.width + spacing
        }

        return size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = proposal.width ?? bounds.width
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + subviewSize.width > bounds.minX + maxWidth {
                origin.x = bounds.minX
                origin.y += lineHeight + lineSpacing
                lineHeight = 0
            }

            subview.place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(subviewSize)
            )

            lineHeight = max(lineHeight, subviewSize.height)
            origin.x += subviewSize.width + spacing
        }
    }
}

private extension String {
    func splitIntoInlineFlowTokens() -> [String] {
        var tokens = [String]()
        var current = ""
        var previousWasWhitespace: Bool?

        for character in self {
            let isWhitespace = character.isWhitespace
            if let previousWasWhitespace, previousWasWhitespace != isWhitespace, !current.isEmpty {
                tokens.append(current)
                current.removeAll(keepingCapacity: true)
            }
            current.append(character)
            previousWasWhitespace = isWhitespace
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
