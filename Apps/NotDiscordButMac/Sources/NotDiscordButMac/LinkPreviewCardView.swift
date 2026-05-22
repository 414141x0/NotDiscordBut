import DiscordKit
import SwiftUI

struct LinkPreviewCardView: View {
    let preview: LinkPreviewBlock
    let embed: DiscordMessageEmbed?

    @Environment(\.openURL)
    private var openURL

    @State
    private var metadata: LinkPreviewMetadata?
    @State
    private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let previewImageURL {
                RemoteAssetView(
                    url: previewImageURL,
                    kind: .linkPreview,
                    animationPolicy: .never,
                    scalingMode: .fit
                ) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.quaternary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120, idealHeight: 180, maxHeight: 220)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: 18,
                            bottomLeading: 0,
                            bottomTrailing: 0,
                            topTrailing: 18
                        ),
                        style: .continuous
                    )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(resolvedTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if let summary = primarySummary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let secondarySummary {
                    Text(secondarySummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(isExpanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if shouldShowExpansionControl {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Label(
                            isExpanded ? "Collapse" : "Expand",
                            systemImage: isExpanded ? "chevron.down" : "chevron.right"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Text(resolvedSiteName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(preview.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            openURL(resolvedURL)
        }
        .task(id: preview.url) {
            metadata = await LinkPreviewMetadataStore.shared.metadata(for: preview.url)
        }
    }

    private var resolvedURL: URL {
        metadata?.canonicalURL ?? preview.url
    }

    private var previewImageURL: URL? {
        url(from: embed?.imageURL)
            ?? url(from: embed?.thumbnailURL)
            ?? metadata?.imageURL
    }

    private var resolvedTitle: String {
        embed?.title ?? metadata?.title ?? preview.url.host ?? preview.url.absoluteString
    }

    private var primarySummary: String? {
        normalized(embed?.description) ?? normalized(metadata?.summary)
    }

    private var secondarySummary: String? {
        guard
            let embedDescription = normalized(embed?.description),
            let metadataSummary = normalized(metadata?.summary),
            embedDescription != metadataSummary
        else {
            return nil
        }
        return metadataSummary
    }

    private var resolvedSiteName: String {
        normalized(metadata?.siteName) ?? preview.url.host() ?? preview.url.host ?? "Link"
    }

    private var shouldShowExpansionControl: Bool {
        if let primarySummary, primarySummary.count > 160 {
            return true
        }
        if let secondarySummary, secondarySummary.count > 110 {
            return true
        }
        return resolvedTitle.count > 90
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            shape.fill(.bar)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func url(from source: String?) -> URL? {
        guard let source else {
            return nil
        }
        return URL(string: source)
    }
}
