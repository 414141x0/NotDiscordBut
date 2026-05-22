import DiscordKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct IOSMessageBubble: View {
    let message: ClusteredMessageProjection
    let guildID: GuildID?
    let author: DiscordUser
    let displayName: String

    @Environment(IOSAppModel.self) private var model
    @State private var focusedMedia: FocusedMediaItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reference = message.message.messageReference,
               let referencedMessage = message.message.referencedMessage {
                IOSReplyBanner(
                    reference: reference,
                    referencedMessage: referencedMessage
                )
            }

            ForEach(message.blocks, id: \.blockID) { block in
                switch block {
                case let .text(textBlock):
                    Text(textBlock.content)
                        .font(.body)
                        .textSelection(.enabled)
                case let .linkPreview(linkPreview):
                    IOSLinkPreviewCard(preview: linkPreview)
                }
            }

            if !message.message.attachments.isEmpty {
                attachmentsView
            }

            if !message.message.embeds.isEmpty {
                embedsView
            }

            if !message.message.reactions.isEmpty {
                IOSReactionBar(
                    reactions: message.message.reactions,
                    message: message.message,
                    guildID: guildID
                )
            }
        }
        .contextMenu {
            contextMenuItems
        }
        #if os(iOS)
        .fullScreenCover(item: $focusedMedia) { media in
            IOSMediaViewer(item: media)
        }
        #else
        .sheet(item: $focusedMedia) { media in
            IOSMediaViewer(item: media)
        }
        #endif
    }

    @ViewBuilder
    private var attachmentsView: some View {
        ForEach(message.message.attachments, id: \.id) { attachment in
            if let url = attachment.imageDisplayURL {
                Button {
                    focusedMedia = FocusedMediaItem(url: url, contentType: .image)
                } label: {
                    RemoteAssetView(
                        url: url,
                        kind: .inlineMedia,
                        scalingMode: .fit
                    ) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.quaternary)
                            .frame(height: 180)
                    }
                    .frame(maxWidth: 280, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                    Text(attachment.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            }
        }
    }

    @ViewBuilder
    private var embedsView: some View {
        ForEach(Array(message.message.embeds.enumerated()), id: \.offset) { _, embed in
            if embed.title != nil || embed.description != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let embedTitle = embed.title {
                        Text(embedTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                    }
                    if let description = embed.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                    if let imageURLString = embed.imageURL ?? embed.thumbnailURL,
                       let imageURL = URL(string: imageURLString) {
                        RemoteAssetView(
                            url: imageURL,
                            kind: .inlineMedia,
                            scalingMode: .fit
                        ) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.quaternary)
                                .frame(height: 100)
                        }
                        .frame(maxWidth: 260, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary))
            }
        }
    }

    private static func copyToClipboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            let target = MessageReplyTarget(
                channelID: message.message.channelID,
                messageID: message.id,
                guildID: guildID,
                authorDisplayName: displayName,
                previewText: String(message.message.content.prefix(100))
            )
            model.composer.beginReply(target)
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }

        Button {
            Self.copyToClipboard(message.message.content)
        } label: {
            Label("Copy Text", systemImage: "doc.on.doc")
        }

        let actionTarget = MessageActionTarget(
            channelID: message.message.channelID,
            messageID: message.id,
            guildID: guildID,
            authorID: author.id,
            authorDisplayName: displayName,
            previewText: String(message.message.content.prefix(100))
        )

        Button {
            Self.copyToClipboard(actionTarget.messageLink)
        } label: {
            Label("Copy Link", systemImage: "link")
        }
    }
}

struct FocusedMediaItem: Identifiable, Hashable {
    let url: URL
    let contentType: MediaContentType

    var id: URL { url }

    enum MediaContentType: Hashable {
        case image
        case video
    }
}

private extension DiscordMessageAttachment {
    var imageDisplayURL: URL? {
        let isImage: Bool
        if let contentType, contentType.hasPrefix("image/") {
            isImage = true
        } else if filename.hasSuffix(".png") || filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg") || filename.hasSuffix(".gif") || filename.hasSuffix(".webp") {
            isImage = true
        } else {
            isImage = false
        }

        guard isImage else {
            return nil
        }

        if let proxyURL {
            return URL(string: proxyURL)
        }
        return URL(string: url)
    }
}

private extension MessageRenderBlock {
    var blockID: String {
        switch self {
        case let .text(block):
            return block.id
        case let .linkPreview(block):
            return block.id
        }
    }
}
