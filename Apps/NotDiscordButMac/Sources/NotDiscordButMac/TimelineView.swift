import DiscordKit
import Observation
import SwiftUI

struct TimelineView: View {
    @Bindable var timeline: TimelineModel
    @Bindable var composer: ComposerModel
    let badgeSnapshot: NotificationBadgeSnapshot
    let availableGuildEmojis: [DiscordGuildEmoji]
    let onSend: () -> Void
    let onInspectUser: (UserID) -> Void
    let onPrefetchUserProfile: (UserID) -> Void
    let profilePreview: (UserID) -> UserInspectorProjection?
    let onJumpToReplyReference: (DiscordMessageReference) -> Void
    let onRefreshLatest: () async -> Void
    let onToggleReaction: (DiscordMessage, DiscordReactionEmoji) async -> Void

    @AppStorage("compactTimeline")
    private var compactTimeline = false

    @AppStorage("timelineFontSize")
    private var timelineFontSize = 14.0

    @State
    private var focusedMedia: FocusedMediaPresentation?

    @State
    private var timelineOverscroll: CGFloat = 0

    @State
    private var refreshArmed = false

    @State
    private var activeHoverCard: HoverCardState?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                content
                Divider()
                composerBar
            }

            if let focusedMedia {
                FocusedMediaOverlay(
                    media: focusedMedia,
                    onClose: {
                        self.focusedMedia = nil
                    }
                )
                .transition(.opacity)
                .zIndex(50)
            }
        }
        .animation(.snappy(duration: 0.18), value: focusedMedia)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeline.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(timeline.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Label("\(badgeSnapshot.pendingMessageCount)", systemImage: "clock.badge.exclamationmark")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if timeline.selectedChannel == nil || !timeline.rendersTimeline || timeline.displayedMessageCount == 0 {
            emptyState
        } else {
            GeometryReader { containerProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: compactTimeline ? 12 : 18) {
                        ForEach(timeline.displayedClusters) { cluster in
                            MessageClusterRow(
                                cluster: cluster,
                                guildID: timeline.selectedChannel?.guildID,
                                fontSize: timelineFontSize,
                                compact: compactTimeline,
                                availableGuildEmojis: availableGuildEmojis,
                                onInspectUser: onInspectUser,
                                onPrefetchUserProfile: onPrefetchUserProfile,
                                profilePreview: profilePreview,
                                onJumpToReplyReference: onJumpToReplyReference,
                                onFocusMedia: { media in
                                    focusedMedia = media
                                },
                                onReplyToMessage: { composer.beginReply($0) },
                                onToggleReaction: onToggleReaction,
                                onHoverCardChange: { state in
                                    activeHoverCard = state
                                }
                            )
                        }

                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: TimelineBottomOverscrollPreferenceKey.self,
                                    value: max(0, proxy.frame(in: .named("timeline-scroll")).maxY - containerProxy.size.height)
                                )
                        }
                        .frame(height: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .scrollTargetLayout()
                }
                .coordinateSpace(name: "timeline-scroll")
                .coordinateSpace(name: "timeline-container")
                .textSelection(.enabled)
                .scrollIndicators(.visible)
                .scrollPosition(id: Binding(
                    get: { timeline.currentScrollMessageIDRaw },
                    set: { timeline.updateScrollMessageID($0) }
                ))
                .onPreferenceChange(TimelineBottomOverscrollPreferenceKey.self) { value in
                    timelineOverscroll = value
                    guard value > 52 else {
                        refreshArmed = false
                        return
                    }
                    guard !refreshArmed else {
                        return
                    }
                    refreshArmed = true
                    Task {
                        await onRefreshLatest()
                    }
                }
                .overlay(alignment: .topLeading) {
                    hoverCardOverlay
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            timeline.emptyStateTitle,
            systemImage: timeline.selectedChannel == nil ? "bubble.left.and.text.bubble.right" : "ellipsis.message",
            description: Text(timeline.emptyStateDescription)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let replyTarget = composer.replyTarget {
                ComposerReplyBanner(
                    replyTarget: replyTarget,
                    onCancel: {
                        composer.cancelReply()
                    }
                )
            }

            HStack(alignment: .center, spacing: 12) {
                TextField(
                    composerPlaceholder,
                    text: $composer.draft
                )
                .textFieldStyle(.roundedBorder)
                .disabled(composer.selectedChannelID == nil || composer.isSending)
                .onSubmit {
                    onSend()
                }

                Button("Send", action: onSend)
                    .buttonStyle(.borderedProminent)
                    .disabled(!composer.canSend)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .topLeading) {
            if let errorMessage = composer.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
                    .offset(y: -14)
            }
        }
    }

    private var composerPlaceholder: String {
        if composer.selectedChannelID == nil {
            return "Select a text conversation first"
        }
        return "Message \(timeline.title)"
    }

    @ViewBuilder
    private var hoverCardOverlay: some View {
        if let card = activeHoverCard {
            ProfileHoverCardView(
                user: card.user,
                projection: card.projection,
                onOpenInspector: card.onOpenInspector
            )
            .onHover { inside in
                if inside {
                    card.onCardEnter()
                } else {
                    card.onCardExit()
                }
            }
            .position(
                x: card.avatarFrame.maxX + 14 + 160,
                y: card.avatarFrame.midY
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .leading)))
            .animation(.snappy(duration: 0.18), value: card.user.id)
        }
    }
}

private struct ComposerReplyBanner: View {
    let replyTarget: MessageReplyTarget
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(replyTarget.authorDisplayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(replyTarget.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(replyBannerBackground)
    }

    @ViewBuilder
    private var replyBannerBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    shape.strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
        } else {
            shape.fill(.thinMaterial)
        }
    }
}

struct HoverCardState: Equatable {
    let user: DiscordUser
    let projection: UserInspectorProjection?
    let avatarFrame: CGRect
    let onOpenInspector: () -> Void
    let onCardEnter: () -> Void
    let onCardExit: () -> Void

    static func == (lhs: HoverCardState, rhs: HoverCardState) -> Bool {
        lhs.user.id == rhs.user.id && lhs.avatarFrame == rhs.avatarFrame
    }
}

private struct MessageClusterRow: View {
    let cluster: MessageClusterProjection
    let guildID: GuildID?
    let fontSize: Double
    let compact: Bool
    let availableGuildEmojis: [DiscordGuildEmoji]
    let onInspectUser: (UserID) -> Void
    let onPrefetchUserProfile: (UserID) -> Void
    let profilePreview: (UserID) -> UserInspectorProjection?
    let onJumpToReplyReference: (DiscordMessageReference) -> Void
    let onFocusMedia: (FocusedMediaPresentation) -> Void
    let onReplyToMessage: (MessageReplyTarget) -> Void
    let onToggleReaction: (DiscordMessage, DiscordReactionEmoji) async -> Void
    let onHoverCardChange: (HoverCardState?) -> Void

    @State
    private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HoverProfileAnchor(
                user: cluster.author,
                projection: profilePreview(cluster.author.id),
                compact: compact,
                onPrefetchUserProfile: onPrefetchUserProfile,
                onHoverCardChange: onHoverCardChange,
                onOpenInspector: {
                    onInspectUser(cluster.author.id)
                }
            )

            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                header

                ForEach(cluster.messages) { message in
                    ClusteredMessageBody(
                        cluster: cluster,
                        message: message,
                        guildID: guildID,
                        fontSize: fontSize,
                        compact: compact,
                        availableGuildEmojis: availableGuildEmojis,
                        onInspectUser: onInspectUser,
                        onJumpToReplyReference: onJumpToReplyReference,
                        onFocusMedia: onFocusMedia,
                        onReplyToMessage: onReplyToMessage,
                        onToggleReaction: onToggleReaction
                    )
                    .id(message.id.rawValue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(clusterBackground)
        .onHover { inside in
            hovered = inside
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    onInspectUser(cluster.author.id)
                } label: {
                    Text(cluster.displayName)
                        .font(.system(size: fontSize - 1, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(discordAccent: cluster.displayAccentColor))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Text(cluster.author.tag)
                    .font(.system(size: fontSize - 2, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(timeRangeText)
                .font(.system(size: fontSize - 2, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var clusterBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .overlay {
                    shape.fill(.white.opacity(hovered ? 0.08 : 0.03))
                }
        } else {
            shape.fill(hovered ? .regularMaterial : .thinMaterial)
        }
    }

    private static let timeFormat = Date.FormatStyle(date: .omitted, time: .shortened)

    private var timeRangeText: String {
        let start = cluster.startedAt.formatted(Self.timeFormat)
        let end = cluster.endedAt.formatted(Self.timeFormat)
        return start == end ? start : "\(start) - \(end)"
    }
}

private struct HoverProfileAnchor: View {
    let user: DiscordUser
    let projection: UserInspectorProjection?
    let compact: Bool
    let onPrefetchUserProfile: (UserID) -> Void
    let onHoverCardChange: (HoverCardState?) -> Void
    let onOpenInspector: () -> Void

    @State
    private var hoverController = ProfileHoverController()

    var body: some View {
        let avatarSize = compact ? 34.0 : 42.0

        DiscordAvatarView(user: user, size: avatarSize)
            .frame(width: avatarSize, height: avatarSize, alignment: .topLeading)
            .background {
                GeometryReader { geo in
                    let controller = hoverController
                    Color.clear
                        .onChange(of: controller.isPresented) { _, isPresented in
                            if isPresented {
                                let frame = geo.frame(in: .named("timeline-container"))
                                onHoverCardChange(HoverCardState(
                                    user: user,
                                    projection: projection,
                                    avatarFrame: frame,
                                    onOpenInspector: onOpenInspector,
                                    onCardEnter: { controller.enterCard() },
                                    onCardExit: { controller.exitCard() }
                                ))
                            } else {
                                onHoverCardChange(nil)
                            }
                        }
                }
            }
            .onHover { inside in
                if inside {
                    onPrefetchUserProfile(user.id)
                    hoverController.enterAvatar()
                } else {
                    hoverController.exitAvatar()
                }
            }
            .animation(.snappy(duration: 0.18), value: hoverController.isPresented)
    }
}

private struct ClusteredMessageBody: View {
    @Environment(\.openWindow) private var openWindow

    let cluster: MessageClusterProjection
    let message: ClusteredMessageProjection
    let guildID: GuildID?
    let fontSize: Double
    let compact: Bool
    let availableGuildEmojis: [DiscordGuildEmoji]
    let onInspectUser: (UserID) -> Void
    let onJumpToReplyReference: (DiscordMessageReference) -> Void
    let onFocusMedia: (FocusedMediaPresentation) -> Void
    let onReplyToMessage: (MessageReplyTarget) -> Void
    let onToggleReaction: (DiscordMessage, DiscordReactionEmoji) async -> Void

    @State
    private var actionsPresented = false

    @State
    private var showingReactionPicker = false

    @State
    private var reactionSearchText = ""

    @State
    private var hoverLocation: CGPoint?

    @State
    private var actionDockHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            if let messageReference = message.message.messageReference {
                ReplyReferenceView(
                    reference: messageReference,
                    referencedMessage: message.message.referencedMessage,
                    didLoadReferencedMessage: message.message.didLoadReferencedMessage,
                    fontSize: fontSize,
                    onActivate: {
                        onJumpToReplyReference(messageReference)
                    }
                )
            }

            ForEach(Array(message.blocks.enumerated()), id: \.element.id) { _, block in
                MessageBlockView(
                    block: block,
                    message: message.message,
                    fontSize: fontSize,
                    previewEmbed: previewEmbedByBlockID[block.id]
                )
            }

            MessageMediaSection(
                attachments: message.message.attachments,
                embeds: remainingEmbeds,
                compact: compact,
                onOpenMedia: onFocusMedia
            )

            if message.message.flags.contains(.loading) {
                Text("Pending send")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !message.message.reactions.isEmpty {
                MessageReactionFooter(
                    reactions: message.message.reactions,
                    onToggleReaction: { emoji in
                        Task {
                            await onToggleReaction(message.message, emoji)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            GeometryReader { proxy in
                if MessageActionDockMetrics.shouldPresentDock(
                    pointerLocation: hoverLocation,
                    messageSize: proxy.size,
                    isDockHovered: actionDockHovered,
                    isMenuPresented: actionsPresented
                ) {
                    MessageActionDock(
                        onReply: beginReply,
                        onReact: presentReactionPicker,
                        onMessageAuthor: openMessageWindow
                    )
                    .padding(.top, 4)
                    .padding(.trailing, 4)
                    .onHover { inside in
                        actionDockHovered = inside
                    }
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing))
                    )
                }
            }
            .animation(.snappy(duration: 0.18), value: actionDockHovered)
            .animation(.snappy(duration: 0.18), value: actionsPresented)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(count: 2) {
            presentActionMenu()
        }
        .contextMenu {
            Button("Reply", systemImage: "arrowshape.turn.up.left") {
                beginReply()
            }

            Button("React…", systemImage: "face.smiling") {
                presentReactionPicker()
            }

            Button("Message…", systemImage: "paperplane") {
                openMessageWindow()
            }
        }
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case let .active(location):
                hoverLocation = location
            case .ended:
                hoverLocation = nil
                actionDockHovered = false
            }
        }
        .popover(isPresented: $actionsPresented, arrowEdge: .top) {
            if showingReactionPicker {
                ReactionPickerPopover(
                    guildEmojis: availableGuildEmojis,
                    searchText: $reactionSearchText,
                    onBack: {
                        showingReactionPicker = false
                    },
                    onSelectUnicodeReaction: { option in
                        Task {
                            await onToggleReaction(
                                message.message,
                                DiscordReactionEmoji(name: option.emoji)
                            )
                        }
                        actionsPresented = false
                    },
                    onSelectGuildEmoji: { emoji in
                        Task {
                            await onToggleReaction(
                                message.message,
                                emoji.reactionEmoji
                            )
                        }
                        actionsPresented = false
                    }
                )
            } else {
                MessageActionPopover(
                    target: actionTarget,
                    onReply: {
                        beginReply()
                    },
                    onReact: {
                        presentReactionPicker()
                    },
                    onMessageAuthor: {
                        openMessageWindow()
                    }
                )
            }
        }
    }

    private func presentActionMenu() {
        reactionSearchText = ""
        showingReactionPicker = false
        actionsPresented = true
    }

    private func presentReactionPicker() {
        reactionSearchText = ""
        showingReactionPicker = true
        actionsPresented = true
    }

    private func beginReply() {
        onReplyToMessage(actionTarget.replyTarget)
        actionsPresented = false
    }

    private func openMessageWindow() {
        openWindow(value: ConversationWindowRoute.directMessage(actionTarget.authorID, actionTarget.messageLink))
        actionsPresented = false
    }

    private var remainingEmbeds: [DiscordMessageEmbed] {
        let previewURLs: Set<String> = Set(
            message.blocks.compactMap { block in
                guard case let .linkPreview(preview) = block else {
                    return nil
                }
                return normalizedURLString(for: preview.url.absoluteString)
            }
        )
        let suppressedPreviewURLs: Set<String> = Set(
            message.blocks
                .flatMap { block -> [String] in
                    guard case let .text(textBlock) = block else {
                        return []
                    }
                    return textBlock.suppressedPreviewURLs
                }
                .map(normalizedURLString(for:))
        )
        let usedPreviewEmbeds = Set(previewEmbedByBlockID.values)

        return message.message.embeds.filter { embed in
            guard !usedPreviewEmbeds.contains(embed) else {
                return false
            }
            guard let url = embed.url else {
                return true
            }
            let normalizedEmbedURL = normalizedURLString(for: url)
            return !previewURLs.contains(normalizedEmbedURL) &&
                !suppressedPreviewURLs.contains(normalizedEmbedURL)
        }
    }

    private var previewEmbedByBlockID: [String: DiscordMessageEmbed] {
        let previewBlocks: [LinkPreviewBlock] = message.blocks.compactMap { block in
            guard case let .linkPreview(preview) = block else {
                return nil
            }
            return preview
        }

        guard !previewBlocks.isEmpty else {
            return [:]
        }

        var remainingEmbeds = message.message.embeds.filter(\.isRenderablePreviewEmbed)
        var mapping = [String: DiscordMessageEmbed]()

        for preview in previewBlocks {
            if let exactIndex = remainingEmbeds.firstIndex(where: { preview.matches(embed: $0) }) {
                mapping[preview.id] = remainingEmbeds.remove(at: exactIndex)
            } else if let fallback = remainingEmbeds.first {
                mapping[preview.id] = fallback
                remainingEmbeds.removeFirst()
            }
        }

        return mapping
    }

    private var actionTarget: MessageActionTarget {
        MessageActionTarget(
            channelID: message.message.channelID,
            messageID: message.id,
            guildID: guildID,
            authorID: cluster.author.id,
            authorDisplayName: cluster.displayName,
            previewText: message.message.actionPreviewText
        )
    }
}

private struct MessageBlockView: View {
    let block: MessageRenderBlock
    let message: DiscordMessage
    let fontSize: Double
    let previewEmbed: DiscordMessageEmbed?

    var body: some View {
        switch block {
        case let .text(textBlock):
            InlineMessageTextView(
                block: textBlock,
                fontSize: fontSize
            )

        case let .linkPreview(preview):
            LinkPreviewCardView(
                preview: preview,
                embed: previewEmbed
            )
        }
    }
}

private struct MessageMediaSection: View {
    let attachments: [DiscordMessageAttachment]
    let embeds: [DiscordMessageEmbed]
    let compact: Bool
    let onOpenMedia: (FocusedMediaPresentation) -> Void

    var body: some View {
        if attachments.isEmpty && embeds.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                ForEach(attachments, id: \.id) { attachment in
                    if attachment.isRenderableImage {
                        Button {
                            onOpenMedia(
                                FocusedMediaPresentation(
                                    url: URL(string: attachment.url),
                                    title: attachment.filename,
                                    kind: .image
                                )
                            )
                        } label: {
                            InlineMediaThumbnail(
                                url: URL(string: attachment.url),
                                idealAspectRatio: attachment.aspectRatio,
                                kind: .inlineMedia
                            )
                        }
                        .buttonStyle(.plain)
                    } else if attachment.isRenderableVideo, let videoURL = URL(string: attachment.url) {
                        InlineVideoPlayerView(
                            url: videoURL,
                            posterURL: URL(string: attachment.proxyURL ?? attachment.url),
                            idealAspectRatio: attachment.aspectRatio,
                            onOpenMedia: {
                                onOpenMedia(
                                    FocusedMediaPresentation(
                                        url: videoURL,
                                        title: attachment.filename,
                                        kind: .video,
                                        posterURL: URL(string: attachment.proxyURL ?? attachment.url)
                                    )
                                )
                            }
                        )
                    } else if let destination = URL(string: attachment.url) {
                        Link(destination: destination) {
                            Label(attachment.filename, systemImage: attachment.linkSymbolName)
                        }
                        .buttonStyle(.link)
                    }
                }

                ForEach(embeds.indices, id: \.self) { index in
                    let embed = embeds[index]
                    if let videoURL = embed.playableVideoURL {
                        InlineVideoPlayerView(
                            url: videoURL,
                            posterURL: embed.previewImageURL,
                            idealAspectRatio: nil,
                            onOpenMedia: {
                                onOpenMedia(
                                    FocusedMediaPresentation(
                                        url: videoURL,
                                        title: embed.title ?? videoURL.lastPathComponent,
                                        kind: .video,
                                        posterURL: embed.previewImageURL
                                    )
                                )
                            }
                        )
                    } else if let url = embed.previewImageURL {
                        Button {
                            onOpenMedia(
                                FocusedMediaPresentation(
                                    url: url,
                                    title: embed.title ?? url.lastPathComponent,
                                    kind: .image
                                )
                            )
                        } label: {
                            InlineMediaThumbnail(
                                url: url,
                                idealAspectRatio: nil,
                                kind: .linkPreview
                            )
                        }
                        .buttonStyle(.plain)
                    } else if let url = embed.url, let destination = URL(string: url) {
                        Link(destination: destination) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(embed.title ?? destination.host ?? destination.absoluteString)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if let description = embed.description, !description.isEmpty {
                                    Text(description)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: 420, alignment: .leading)
                            .background(linkEmbedBackground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linkEmbedBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            shape.fill(.bar)
        }
    }
}

private struct MessageReactionFooter: View {
    let reactions: [DiscordMessageReaction]
    let onToggleReaction: (DiscordReactionEmoji) -> Void

    var body: some View {
        ReactionWrapLayout(spacing: 8, lineSpacing: 8) {
            ForEach(reactions, id: \.emoji) { reaction in
                ReactionPill(
                    reaction: reaction,
                    onToggleReaction: {
                        onToggleReaction(reaction.emoji)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReactionPill: View {
    let reaction: DiscordMessageReaction
    let onToggleReaction: () -> Void

    var body: some View {
        Button(action: onToggleReaction) {
            VStack(spacing: 4) {
                Group {
                    if let imageURL = reaction.emoji.imageURL {
                        RemoteAssetView(
                            url: imageURL,
                            kind: .customEmoji,
                            animationPolicy: reaction.emoji.animated ? .always : .never,
                            scalingMode: .fit,
                            showsBackground: false,
                            isAnimating: reaction.emoji.animated
                        ) {
                            Text(reaction.emoji.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(reaction.emoji.name)
                            .font(.system(size: 18))
                    }
                }
                .frame(width: 22, height: 22)

                Text("\(reaction.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(reaction.me ? .primary : .secondary)
            }
            .frame(minWidth: 44)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(background)
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    shape.strokeBorder(
                        reaction.me ? .white.opacity(0.22) : .white.opacity(0.08),
                        lineWidth: reaction.me ? 1.25 : 1
                    )
                }
        } else {
            shape.fill(reaction.me ? .regularMaterial : .thinMaterial)
        }
    }
}

private struct MessageActionPopover: View {
    let target: MessageActionTarget
    let onReply: () -> Void
    let onReact: () -> Void
    let onMessageAuthor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(target.authorDisplayName)
                .font(.headline)
            Text(target.previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            Button("Reply", systemImage: "arrowshape.turn.up.left") {
                onReply()
            }
            .buttonStyle(.plain)

            Button("React…", systemImage: "face.smiling") {
                onReact()
            }
            .buttonStyle(.plain)

            Button("Message…", systemImage: "paperplane") {
                onMessageAuthor()
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}

private struct MessageActionDock: View {
    let onReply: () -> Void
    let onReact: () -> Void
    let onMessageAuthor: () -> Void

    @State
    private var hoveredAction: DockAction?

    var body: some View {
        HStack(spacing: 8) {
            iconButton(
                action: .reply,
                systemImage: "arrowshape.turn.up.left.fill",
                helpText: "Reply",
                onSelect: onReply
            )
            iconButton(
                action: .react,
                systemImage: "face.smiling.fill",
                helpText: "React",
                onSelect: onReact
            )
            iconButton(
                action: .message,
                systemImage: "paperplane.fill",
                helpText: "Message",
                onSelect: onMessageAuthor
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func iconButton(
        action: DockAction,
        systemImage: String,
        helpText: String,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hoveredAction == action ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(hoveredAction == action ? Color.white.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { inside in
            hoveredAction = inside ? action : (hoveredAction == action ? nil : hoveredAction)
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    shape.strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
        } else {
            shape.fill(.thinMaterial)
        }
    }

    private enum DockAction: Hashable {
        case reply
        case react
        case message
    }
}

private struct ReactionPickerPopover: View {
    let guildEmojis: [DiscordGuildEmoji]
    @Binding var searchText: String
    let onBack: () -> Void
    let onSelectUnicodeReaction: (UnicodeReactionOption) -> Void
    let onSelectGuildEmoji: (DiscordGuildEmoji) -> Void

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 104), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Back", systemImage: "chevron.left") {
                    onBack()
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text("React")
                    .font(.headline)
            }

            TextField("Search emoji", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !filteredGuildEmojis.isEmpty {
                        reactionSection(title: "Guild Emoji") {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                ForEach(filteredGuildEmojis) { emoji in
                                    ReactionChoiceCell(
                                        title: emoji.name,
                                        emojiView: AnyView(
                                            Group {
                                                if let imageURL = emoji.imageURL {
                                                    RemoteAssetView(
                                                        url: imageURL,
                                                        kind: .customEmoji,
                                                        animationPolicy: emoji.animated ? .always : .never,
                                                        scalingMode: .fit,
                                                        showsBackground: false,
                                                        isAnimating: emoji.animated
                                                    ) {
                                                        Text(emoji.name)
                                                            .font(.caption2.weight(.semibold))
                                                            .foregroundStyle(.secondary)
                                                    }
                                                } else {
                                                    Text(emoji.name)
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        ),
                                        action: {
                                            onSelectGuildEmoji(emoji)
                                        }
                                    )
                                }
                            }
                        }
                    }

                    reactionSection(title: "Unicode Emoji") {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(filteredUnicodeOptions) { option in
                                ReactionChoiceCell(
                                    title: option.name,
                                    emojiView: AnyView(
                                        Text(option.emoji)
                                            .font(.system(size: 24))
                                    ),
                                    action: {
                                        onSelectUnicodeReaction(option)
                                    }
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if filteredGuildEmojis.isEmpty && filteredUnicodeOptions.isEmpty {
                ContentUnavailableView(
                    "No Emoji Matches",
                    systemImage: "face.dashed",
                    description: Text("Try a different search term.")
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(width: 430, height: 420, alignment: .topLeading)
    }

    @ViewBuilder
    private func reactionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var filteredGuildEmojis: [DiscordGuildEmoji] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return guildEmojis
        }

        let needle = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return guildEmojis.filter { emoji in
            emoji.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
        }
    }

    private var filteredUnicodeOptions: [UnicodeReactionOption] {
        ReactionPalette.unicodeOptions.filter { $0.matches(searchText: searchText) }
    }
}

private struct ReactionChoiceCell: View {
    let title: String
    let emojiView: AnyView
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                emojiView
                    .frame(width: 30, height: 30)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(choiceBackground)
    }

    @ViewBuilder
    private var choiceBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    shape.strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
        } else {
            shape.fill(.thinMaterial)
        }
    }
}

struct FocusedMediaPresentation: Equatable {
    enum Kind: String, Equatable {
        case image
        case video
    }

    let url: URL?
    let title: String
    var kind: Kind = .image
    var posterURL: URL?
}

struct FocusedMediaOverlayLayout {
    static let maximumMediaSize = CGSize(width: 1_040, height: 760)
    static let horizontalPadding: CGFloat = 32
    static let verticalPadding: CGFloat = 24
    static let mediaTitleSpacing: CGFloat = 18
    static let titleHeight: CGFloat = 32
    static let verticalChromeAllowance = (verticalPadding * 2) + mediaTitleSpacing + titleHeight

    static func mediaFrameSize(in container: CGSize) -> CGSize {
        CGSize(
            width: max(0, min(maximumMediaSize.width, container.width - (horizontalPadding * 2))),
            height: max(0, min(maximumMediaSize.height, container.height - verticalChromeAllowance))
        )
    }
}

private struct InlineMediaThumbnail: View {
    let url: URL?
    let idealAspectRatio: CGFloat?
    let kind: RemoteAssetKind

    var body: some View {
        RemoteAssetView(
            url: url,
            kind: kind,
            animationPolicy: .never,
            scalingMode: .fit
        ) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
        }
        .frame(maxWidth: 440)
        .aspectRatio(idealAspectRatio ?? (16.0 / 9.0), contentMode: .fit)
        .frame(maxHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption.weight(.semibold))
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
                .padding(10)
        }
    }
}

private struct ReplyReferenceView: View {
    let reference: DiscordMessageReference
    let referencedMessage: DiscordReferencedMessage?
    let didLoadReferencedMessage: Bool
    let fontSize: Double
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: fontSize - 3, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(replyTitle)
                        .font(.system(size: fontSize - 2, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(replySummary)
                        .font(.system(size: fontSize - 2, weight: .regular, design: .default))
                        .foregroundStyle(.secondary.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var replyTitle: String {
        if let referencedMessage {
            return "Replying to \(referencedMessage.author.displayName)"
        }
        if didLoadReferencedMessage {
            return "Replying to deleted message"
        }
        return "Reply unavailable"
    }

    private var replySummary: String {
        guard let referencedMessage else {
            return didLoadReferencedMessage ? "Original message was deleted." : "Original message could not be loaded."
        }
        let trimmedContent = referencedMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            return trimmedContent
        }
        if !referencedMessage.attachments.isEmpty {
            return "Attachment"
        }
        if !referencedMessage.embeds.isEmpty {
            return "Embed"
        }
        return "Original message"
    }
}

private struct TimelineBottomOverscrollPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReactionWrapLayout: Layout {
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

private struct FocusedMediaOverlay: View {
    let media: FocusedMediaPresentation
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let mediaFrame = FocusedMediaOverlayLayout.mediaFrameSize(in: proxy.size)

            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.84)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                VStack(spacing: 18) {
                    Spacer(minLength: 0)

                    Group {
                        switch media.kind {
                        case .image:
                            RemoteAssetView(
                                url: media.url,
                                kind: .focusedMedia,
                                animationPolicy: .always,
                                scalingMode: .fit,
                                isAnimating: true
                            ) {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(.quaternary)
                            }

                        case .video:
                            FocusedVideoPlayerView(
                                url: media.url,
                                posterURL: media.posterURL
                            )
                        }
                    }
                    .frame(width: mediaFrame.width, height: mediaFrame.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    }
                    .padding(.horizontal, FocusedMediaOverlayLayout.horizontalPadding)

                    Text(media.title)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .padding(.horizontal, FocusedMediaOverlayLayout.horizontalPadding)

                    Spacer(minLength: 0)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .padding(FocusedMediaOverlayLayout.verticalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onExitCommand(perform: onClose)
        }
    }
}

private extension DiscordMessageAttachment {
    var isRenderableImage: Bool {
        if let contentType, contentType.hasPrefix("image/") {
            return true
        }
        return url.lowercased().hasSuffix(".png") ||
            url.lowercased().hasSuffix(".jpg") ||
            url.lowercased().hasSuffix(".jpeg") ||
            url.lowercased().hasSuffix(".gif") ||
            url.lowercased().hasSuffix(".webp")
    }

    var isRenderableVideo: Bool {
        if let contentType, contentType.hasPrefix("video/") {
            return true
        }

        let loweredURL = url.lowercased()
        return loweredURL.hasSuffix(".mp4") ||
            loweredURL.hasSuffix(".mov") ||
            loweredURL.hasSuffix(".m4v") ||
            loweredURL.hasSuffix(".webm")
    }

    var linkSymbolName: String {
        if let contentType, contentType.hasPrefix("video/") {
            return "play.rectangle"
        }
        return "paperclip"
    }

    var aspectRatio: CGFloat? {
        guard let width, let height, width > 0, height > 0 else {
            return nil
        }
        return CGFloat(width) / CGFloat(height)
    }
}

private extension DiscordReactionEmoji {
    var imageURL: URL? {
        guard let id else {
            return nil
        }

        let format = animated ? "gif" : "png"
        return URL(string: "https://cdn.discordapp.com/emojis/\(id).\(format)?size=64&quality=lossless")
    }
}

private extension DiscordMessage {
    var actionPreviewText: String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            return trimmedContent
        }
        if !attachments.isEmpty {
            return "Attachment"
        }
        if !embeds.isEmpty {
            return "Embed"
        }
        return "Message"
    }
}

private extension DiscordMessageEmbed {
    var isRenderablePreviewEmbed: Bool {
        url != nil || imageURL != nil || thumbnailURL != nil || videoURL != nil || title != nil || description != nil
    }

    var previewImageURL: URL? {
        if let imageURL, let url = URL(string: imageURL) {
            return url
        }
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            return url
        }
        return nil
    }

    var playableVideoURL: URL? {
        if let videoURL, let url = URL(string: videoURL), url.isDirectVideoResource {
            return url
        }
        if type == "video", let url, let destination = URL(string: url), destination.isDirectVideoResource {
            return destination
        }
        return nil
    }
}

private extension LinkPreviewBlock {
    func matches(embed: DiscordMessageEmbed) -> Bool {
        guard let url = embed.url else {
            return false
        }

        let normalizedPreview = normalizedURLString(for: self.url.absoluteString)
        let normalizedEmbed = normalizedURLString(for: url)
        if normalizedPreview == normalizedEmbed {
            return true
        }

        guard
            let previewComponents = URLComponents(url: self.url, resolvingAgainstBaseURL: true),
            let embedComponents = URLComponents(string: url)
        else {
            return false
        }

        return previewComponents.host == embedComponents.host
    }
}

private func normalizedURLString(for source: String) -> String {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed), url.scheme != nil {
        return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    return "https://\(trimmed)".trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}

private extension URL {
    var isDirectVideoResource: Bool {
        let path = pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "webm"].contains(path)
    }
}
