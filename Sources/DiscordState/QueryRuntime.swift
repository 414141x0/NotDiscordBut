import Foundation
import DiscordPrimitives

public struct SidebarProjection: Hashable, Sendable {
    public var friends: [SidebarFriendProjection]
    public var guilds: [DiscordGuild]
    public var privateChannels: [DiscordChannel]

    public init(
        friends: [SidebarFriendProjection] = [],
        guilds: [DiscordGuild],
        privateChannels: [DiscordChannel]
    ) {
        self.friends = friends
        self.guilds = guilds
        self.privateChannels = privateChannels
    }
}

public struct SidebarFriendProjection: Hashable, Sendable {
    public var user: DiscordUser
    public var relationship: DiscordRelationship

    public init(user: DiscordUser, relationship: DiscordRelationship) {
        self.user = user
        self.relationship = relationship
    }
}

public struct TimelineProjection: Hashable, Sendable {
    public var channelID: ChannelID?
    public var messages: [DiscordMessage]

    public init(channelID: ChannelID?, messages: [DiscordMessage]) {
        self.channelID = channelID
        self.messages = messages
    }
}

public struct TimelineEntryProjection: Hashable, Sendable {
    public var message: DiscordMessage
    public var author: DiscordUser
    public var profile: DiscordUserProfile?
    public var displayName: String
    public var renderedContent: String

    public init(
        message: DiscordMessage,
        author: DiscordUser,
        profile: DiscordUserProfile?,
        displayName: String,
        renderedContent: String
    ) {
        self.message = message
        self.author = author
        self.profile = profile
        self.displayName = displayName
        self.renderedContent = renderedContent
    }
}

public struct RichTimelineProjection: Hashable, Sendable {
    public var channelID: ChannelID?
    public var entries: [TimelineEntryProjection]

    public init(channelID: ChannelID?, entries: [TimelineEntryProjection]) {
        self.channelID = channelID
        self.entries = entries
    }
}

public struct ClusteredTimelineProjection: Hashable, Sendable {
    public var channelID: ChannelID?
    public var clusters: [MessageClusterProjection]

    public init(channelID: ChannelID?, clusters: [MessageClusterProjection]) {
        self.channelID = channelID
        self.clusters = clusters
    }

    public var messageCount: Int {
        clusters.reduce(into: 0) { count, cluster in
            count += cluster.messages.count
        }
    }

    public var lastMessageID: MessageID? {
        clusters.last?.messages.last?.id
    }
}

public struct MessageClusterProjection: Identifiable, Hashable, Sendable {
    public var id: String
    public var author: DiscordUser
    public var profile: DiscordUserProfile?
    public var displayName: String
    public var displayAccentColor: Int?
    public var startedAt: Date
    public var endedAt: Date
    public var messages: [ClusteredMessageProjection]

    public init(
        id: String,
        author: DiscordUser,
        profile: DiscordUserProfile?,
        displayName: String,
        displayAccentColor: Int?,
        startedAt: Date,
        endedAt: Date,
        messages: [ClusteredMessageProjection]
    ) {
        self.id = id
        self.author = author
        self.profile = profile
        self.displayName = displayName
        self.displayAccentColor = displayAccentColor
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.messages = messages
    }
}

public struct ClusteredMessageProjection: Identifiable, Hashable, Sendable {
    public var id: MessageID
    public var message: DiscordMessage
    public var blocks: [MessageRenderBlock]

    public init(id: MessageID, message: DiscordMessage, blocks: [MessageRenderBlock]) {
        self.id = id
        self.message = message
        self.blocks = blocks
    }
}

public struct MessageTextBlock: Identifiable, Hashable, Sendable {
    public var id: String
    public var content: AttributedString
    public var fragments: [MessageInlineFragment]
    public var paragraphStyle: MessageParagraphStyle
    public var suppressedPreviewURLs: [String]

    public init(
        id: String,
        content: AttributedString,
        fragments: [MessageInlineFragment]? = nil,
        paragraphStyle: MessageParagraphStyle = .normal,
        suppressedPreviewURLs: [String] = []
    ) {
        self.id = id
        self.content = content
        self.fragments = fragments ?? [
            .text(
                MessageTextFragment(
                    id: "\(id)-fragment-0",
                    content: content
                )
            )
        ]
        self.paragraphStyle = paragraphStyle
        self.suppressedPreviewURLs = suppressedPreviewURLs
    }
}

public enum MessageParagraphStyle: Hashable, Sendable {
    case normal
    case bullet
}

public struct MessageTextFragment: Identifiable, Hashable, Sendable {
    public var id: String
    public var content: AttributedString

    public init(id: String, content: AttributedString) {
        self.id = id
        self.content = content
    }
}

public struct MessageCustomEmojiFragment: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var imageURL: URL?
    public var isAnimated: Bool

    public init(id: String, name: String, imageURL: URL?, isAnimated: Bool) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.isAnimated = isAnimated
    }

    public var fallbackText: String {
        ":\(name):"
    }
}

public enum MessageInlineFragment: Identifiable, Hashable, Sendable {
    case text(MessageTextFragment)
    case customEmoji(MessageCustomEmojiFragment)

    public var id: String {
        switch self {
        case let .text(fragment):
            fragment.id
        case let .customEmoji(fragment):
            fragment.id
        }
    }
}

public struct LinkPreviewBlock: Identifiable, Hashable, Sendable {
    public var id: String
    public var url: URL

    public init(id: String, url: URL) {
        self.id = id
        self.url = url
    }
}

public enum MessageRenderBlockKind: Hashable, Sendable {
    case text
    case linkPreview
}

public enum MessageRenderBlock: Identifiable, Hashable, Sendable {
    case text(MessageTextBlock)
    case linkPreview(LinkPreviewBlock)

    public var id: String {
        switch self {
        case let .text(block):
            block.id
        case let .linkPreview(block):
            block.id
        }
    }

    public var kind: MessageRenderBlockKind {
        switch self {
        case .text:
            .text
        case .linkPreview:
            .linkPreview
        }
    }
}

public struct ChannelListProjection: Hashable, Sendable {
    public var guildID: GuildID?
    public var channels: [DiscordChannel]

    public init(guildID: GuildID?, channels: [DiscordChannel]) {
        self.guildID = guildID
        self.channels = channels
    }
}

public struct GuildEmojiInventoryProjection: Hashable, Sendable {
    public var guildID: GuildID
    public var emojis: [DiscordGuildEmoji]

    public init(guildID: GuildID, emojis: [DiscordGuildEmoji]) {
        self.guildID = guildID
        self.emojis = emojis
    }
}

public struct UserInspectorProjection: Hashable, Sendable {
    public var user: DiscordUser
    public var profile: DiscordUserProfile?
    public var guildMember: DiscordGuildMemberProfile?
    public var resolvedRoles: [DiscordGuildRole]
    public var displayAccentColor: Int?
    public var mutualGuilds: [DiscordGuild]
    public var mutualFriends: [DiscordUser]

    public init(
        user: DiscordUser,
        profile: DiscordUserProfile?,
        guildMember: DiscordGuildMemberProfile?,
        resolvedRoles: [DiscordGuildRole],
        displayAccentColor: Int?,
        mutualGuilds: [DiscordGuild],
        mutualFriends: [DiscordUser]
    ) {
        self.user = user
        self.profile = profile
        self.guildMember = guildMember
        self.resolvedRoles = resolvedRoles
        self.displayAccentColor = displayAccentColor
        self.mutualGuilds = mutualGuilds
        self.mutualFriends = mutualFriends
    }
}

public final class QueryRuntime: Sendable {
    private static let linkExpression = try! NSRegularExpression(
        pattern: #"(?:https?://)?(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(?:/[^\s<>()]*)?"#
    )
    private static let customEmojiExpression = try! NSRegularExpression(
        pattern: #"<(a?):([A-Za-z0-9_~\-]+):([0-9]+)>"#
    )
    private static let mentionExpression = try! NSRegularExpression(
        pattern: #"<@!?([0-9]+)>"#
    )
    private static let autolinkExpression = try! NSRegularExpression(
        pattern: #"<(https?://[^>\s]+)>"#
    )

    public init() {}

    public func sidebarProjection(from state: NormalizedState) -> SidebarProjection {
        SidebarProjection(
            friends: state.relationships.values
                .compactMap { relationship in
                    guard let user = state.users[relationship.userID.rawValue] else {
                        return nil
                    }
                    return SidebarFriendProjection(user: user, relationship: relationship)
                }
                .sorted { lhs, rhs in
                    if lhs.relationship.kind == rhs.relationship.kind {
                        let leftName = lhs.user.globalName ?? lhs.user.username
                        let rightName = rhs.user.globalName ?? rhs.user.username
                        return leftName.localizedStandardCompare(rightName) == .orderedAscending
                    }
                    return lhs.relationship.kind.sortIndex < rhs.relationship.kind.sortIndex
                },
            guilds: state.guilds.values.sorted { lhs, rhs in
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return comparison == .orderedAscending
            },
            privateChannels: state.channels.values
                .filter { $0.guildID == nil }
                .sorted { lhs, rhs in
                    let leftName = lhs.name ?? lhs.id.rawValue
                    let rightName = rhs.name ?? rhs.id.rawValue
                    let comparison = leftName.localizedStandardCompare(rightName)
                    if comparison == .orderedSame {
                        return lhs.id < rhs.id
                    }
                    return comparison == .orderedAscending
                }
        )
    }

    public func timelineProjection(for channelID: ChannelID?, from state: NormalizedState) -> TimelineProjection {
        let messages = state.messages.values
            .filter { message in
                channelID == nil || message.channelID == channelID
            }
            .sorted { $0.timestamp < $1.timestamp }

        return TimelineProjection(channelID: channelID, messages: messages)
    }

    public func richTimelineProjection(for channelID: ChannelID?, from state: NormalizedState) -> RichTimelineProjection {
        richTimelineProjection(for: timelineProjection(for: channelID, from: state).messages, channelID: channelID, from: state)
    }

    public func richTimelineProjection(
        for messages: [DiscordMessage],
        channelID: ChannelID?,
        from state: NormalizedState
    ) -> RichTimelineProjection {
        let entries: [TimelineEntryProjection] = messages.compactMap { message in
            guard let author = state.users[message.authorID.rawValue] else {
                return nil
            }

            let profile = state.userProfiles[author.id.rawValue]
            let displayName = message.memberNickname ?? profile?.guildMember?.nickname ?? author.displayName
            return TimelineEntryProjection(
                message: message,
                author: author,
                profile: profile,
                displayName: displayName,
                renderedContent: renderedContent(for: message, from: state)
            )
        }

        return RichTimelineProjection(channelID: channelID, entries: entries)
    }

    public func clusteredTimelineProjection(for channelID: ChannelID?, from state: NormalizedState) -> ClusteredTimelineProjection {
        clusteredTimelineProjection(
            for: timelineProjection(for: channelID, from: state).messages,
            channelID: channelID,
            from: state
        )
    }

    public func clusteredTimelineProjection(
        for messages: [DiscordMessage],
        channelID: ChannelID?,
        from state: NormalizedState
    ) -> ClusteredTimelineProjection {
        let authoredMessages: [(DiscordMessage, DiscordUser, DiscordUserProfile?, String)] = messages.compactMap { message in
            guard let author = state.users[message.authorID.rawValue] else {
                return nil
            }

            let profile = state.userProfiles[author.id.rawValue]
            let displayName = message.memberNickname ?? profile?.guildMember?.nickname ?? author.displayName
            return (message, author, profile, displayName)
        }

        var clusters: [MessageClusterProjection] = []
        var currentGroup: [(DiscordMessage, DiscordUser, DiscordUserProfile?, String)] = []

        for entry in authoredMessages {
            if let previous = currentGroup.last, shouldStartNewCluster(previous: previous.0, next: entry.0) {
                clusters.append(cluster(from: currentGroup, state: state))
                currentGroup.removeAll(keepingCapacity: true)
            }
            currentGroup.append(entry)
        }

        if !currentGroup.isEmpty {
            clusters.append(cluster(from: currentGroup, state: state))
        }

        return ClusteredTimelineProjection(channelID: channelID, clusters: clusters)
    }

    public func channelListProjection(for guildID: GuildID?, from state: NormalizedState) -> ChannelListProjection {
        let channels = state.channels.values
            .filter { channel in
                channel.guildID == guildID
            }
            .sorted { lhs, rhs in
                if lhs.position != rhs.position {
                    return (lhs.position ?? .max) < (rhs.position ?? .max)
                }

                if lhs.kind != rhs.kind {
                    return lhs.kind.sortPriority < rhs.kind.sortPriority
                }

                let leftName = lhs.name ?? lhs.id.rawValue
                let rightName = rhs.name ?? rhs.id.rawValue
                let comparison = leftName.localizedStandardCompare(rightName)
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return comparison == .orderedAscending
            }

        return ChannelListProjection(guildID: guildID, channels: channels)
    }

    public func guildEmojiInventoryProjection(for guildID: GuildID?, from state: NormalizedState) -> GuildEmojiInventoryProjection? {
        guard let guildID else {
            return nil
        }

        let emojis = state.guildEmojis.values
            .filter { $0.guildID == guildID }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return comparison == .orderedAscending
            }

        return GuildEmojiInventoryProjection(guildID: guildID, emojis: emojis)
    }

    public func userInspectorProjection(for userID: UserID, from state: NormalizedState) -> UserInspectorProjection? {
        guard let user = state.users[userID.rawValue] else {
            return nil
        }

        let profile = state.userProfiles[userID.rawValue]
        let guildMember = profile?.guildMember
        let resolvedRoles = resolvedRoles(for: guildMember?.roleIDs ?? [], in: state, guildID: guildMember?.guildID)
        let mutualGuilds = (profile?.mutualGuilds ?? [])
            .compactMap { state.guilds[$0.guildID.rawValue] }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let mutualFriends = (profile?.mutualFriendIDs ?? [])
            .compactMap { state.users[$0.rawValue] }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        return UserInspectorProjection(
            user: user,
            profile: profile,
            guildMember: guildMember,
            resolvedRoles: resolvedRoles,
            displayAccentColor: resolvedRoles.first(where: { $0.color != 0 })?.color ?? profile?.accentColor ?? user.accentColor,
            mutualGuilds: mutualGuilds,
            mutualFriends: mutualFriends
        )
    }
}

private extension QueryRuntime {
    func cluster(
        from group: [(DiscordMessage, DiscordUser, DiscordUserProfile?, String)],
        state: NormalizedState
    ) -> MessageClusterProjection {
        let first = group[0]
        let messages = group.map { message, _, _, _ in
            ClusteredMessageProjection(
                id: message.id,
                message: message,
                blocks: renderBlocks(for: message, from: state)
            )
        }

        return MessageClusterProjection(
            id: first.0.id.rawValue,
            author: first.1,
            profile: first.2,
            displayName: first.3,
            displayAccentColor: resolvedAccentColor(for: first.1, profile: first.2, message: first.0, state: state),
            startedAt: first.0.timestamp,
            endedAt: group.last?.0.timestamp ?? first.0.timestamp,
            messages: messages
        )
    }

    func shouldStartNewCluster(previous: DiscordMessage, next: DiscordMessage) -> Bool {
        if previous.authorID != next.authorID {
            return true
        }

        if next.timestamp.timeIntervalSince(previous.timestamp) > 5 * 60 {
            return true
        }

        if previous.channelID != next.channelID {
            return true
        }

        return false
    }

    func resolvedAccentColor(
        for user: DiscordUser,
        profile: DiscordUserProfile?,
        message: DiscordMessage,
        state: NormalizedState
    ) -> Int? {
        if let guildID = state.channels[message.channelID.rawValue]?.guildID {
            let roleIDs: [RoleID]
            if !message.memberRoleIDs.isEmpty {
                roleIDs = message.memberRoleIDs
            } else if profile?.guildMember?.guildID == guildID {
                roleIDs = profile?.guildMember?.roleIDs ?? []
            } else {
                roleIDs = []
            }

            if let roleColor = resolvedRoles(for: roleIDs, in: state, guildID: guildID).first(where: { $0.color != 0 })?.color {
                return roleColor
            }
        }

        return profile?.accentColor ?? user.accentColor
    }

    func resolvedRoles(
        for roleIDs: [RoleID],
        in state: NormalizedState,
        guildID: GuildID?
    ) -> [DiscordGuildRole] {
        roleIDs
            .compactMap { state.guildRoles[$0.rawValue] }
            .filter { guildID == nil || $0.guildID == guildID }
            .sorted { lhs, rhs in
                if lhs.position != rhs.position {
                    return lhs.position > rhs.position
                }
                return lhs.id < rhs.id
            }
    }

    func renderBlocks(for message: DiscordMessage, from state: NormalizedState) -> [MessageRenderBlock] {
        let lines = message.content.split(separator: "\n", omittingEmptySubsequences: false)

        var blocks: [MessageRenderBlock] = []
        blocks.reserveCapacity(lines.count * 2)

        for (index, line) in lines.enumerated() {
            let content = String(line)
            guard !content.isEmpty else {
                continue
            }

            let text = attributedTextBlock(
                for: content,
                blockID: "\(message.id.rawValue)-text-\(index)",
                from: state
            )
            blocks.append(.text(text))

            let suppressedPreviewURLs = Set(text.suppressedPreviewURLs)
            let visibleLinks = detectedLinks(in: String(text.content.characters))
                .filter { !suppressedPreviewURLs.contains($0.1.absoluteString) }

            for (previewIndex, detectedLink) in visibleLinks.enumerated() {
                blocks.append(
                    .linkPreview(
                        LinkPreviewBlock(
                            id: "\(message.id.rawValue)-preview-\(index)-\(previewIndex)",
                            url: detectedLink.1
                        )
                    )
                )
            }
        }

        return blocks
    }

    func attributedTextBlock(
        for source: String,
        blockID: String,
        from state: NormalizedState
    ) -> MessageTextBlock {
        let parsed = parsedTextLine(for: source, blockID: blockID, from: state)
        return MessageTextBlock(
            id: blockID,
            content: attributedContent(for: parsed.plainText),
            fragments: parsed.fragments,
            paragraphStyle: parsed.paragraphStyle,
            suppressedPreviewURLs: parsed.suppressedPreviewURLs
        )
    }

    func detectedLinks(in source: String) -> [(Range<String.Index>, URL)] {
        let sourceText = source as NSString
        let matches = Self.linkExpression.matches(in: source, range: NSRange(location: 0, length: sourceText.length))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: source) else {
                return nil
            }
            guard let url = canonicalURL(for: String(source[range])) else {
                return nil
            }
            return (range, url)
        }
    }

    func firstPreviewURL(in source: String) -> URL? {
        detectedLinks(in: source).first?.1
    }

    func canonicalURL(for source: String) -> URL? {
        if let url = URL(string: source), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(source)")
    }

    func renderedContent(for message: DiscordMessage, from state: NormalizedState) -> String {
        message.content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                parsedTextLine(
                    for: String(line),
                    blockID: "\(message.id.rawValue)-rendered",
                    from: state
                ).plainText
            }
            .joined(separator: "\n")
    }

    private func attributedContent(for source: String) -> AttributedString {
        var attributed = AttributedString(source)
        for (range, url) in detectedLinks(in: source) {
            guard let attributedRange = Range(range, in: attributed) else {
                continue
            }
            attributed[attributedRange].link = url
        }
        return attributed
    }

    private func parsedTextLine(
        for source: String,
        blockID: String,
        from state: NormalizedState
    ) -> ParsedTextLine {
        let normalizedLine = normalizedTextLine(for: source)
        let matches = customEmojiMatches(in: normalizedLine.visibleText)
        guard !matches.isEmpty else {
            let resolved = replacingMentions(in: normalizedLine.visibleText, from: state)
            return ParsedTextLine(
                plainText: resolved,
                fragments: [
                    .text(
                        MessageTextFragment(
                            id: "\(blockID)-text-0",
                            content: attributedContent(for: resolved)
                        )
                    )
                ],
                paragraphStyle: normalizedLine.paragraphStyle,
                suppressedPreviewURLs: normalizedLine.suppressedPreviewURLs
            )
        }

        let sourceText = normalizedLine.visibleText as NSString
        var fragments: [MessageInlineFragment] = []
        var rendered = ""
        var cursor = 0
        var fragmentIndex = 0

        func appendText(_ text: String) {
            let resolved = replacingMentions(in: text, from: state)
            guard !resolved.isEmpty else {
                return
            }
            rendered.append(resolved)
            let textFragments = tokenizedTextFragments(
                for: resolved,
                blockID: "\(blockID)-text-\(fragmentIndex)"
            )
            fragments.append(contentsOf: textFragments)
            fragmentIndex += textFragments.count
        }

        for match in matches {
            let matchRange = match.range
            if matchRange.location > cursor {
                appendText(
                    sourceText.substring(
                        with: NSRange(location: cursor, length: matchRange.location - cursor)
                    )
                )
            }

            let animated = match.range(at: 1).location != NSNotFound && match.range(at: 1).length > 0
            let name = sourceText.substring(with: match.range(at: 2))
            let identifier = sourceText.substring(with: match.range(at: 3))
            let emoji = MessageCustomEmojiFragment(
                id: "\(blockID)-emoji-\(fragmentIndex)",
                name: name,
                imageURL: customEmojiURL(for: identifier, animated: animated),
                isAnimated: animated
            )
            fragments.append(.customEmoji(emoji))
            rendered.append(emoji.fallbackText)
            fragmentIndex += 1
            cursor = matchRange.location + matchRange.length
        }

        if cursor < sourceText.length {
            appendText(sourceText.substring(from: cursor))
        }

        return ParsedTextLine(
            plainText: rendered,
            fragments: fragments,
            paragraphStyle: normalizedLine.paragraphStyle,
            suppressedPreviewURLs: normalizedLine.suppressedPreviewURLs
        )
    }

    private func tokenizedTextFragments(for source: String, blockID: String) -> [MessageInlineFragment] {
        let components = source.matches(of: /\s*\S+\s*|\s+/)
        guard !components.isEmpty else {
            return [
                .text(
                    MessageTextFragment(
                        id: "\(blockID)-0",
                        content: attributedContent(for: source)
                    )
                )
            ]
        }

        return components.enumerated().map { index, match in
            .text(
                MessageTextFragment(
                    id: "\(blockID)-\(index)",
                    content: attributedContent(for: String(match.0))
                )
            )
        }
    }

    private func customEmojiMatches(in source: String) -> [NSTextCheckingResult] {
        let sourceText = source as NSString
        return Self.customEmojiExpression.matches(in: source, range: NSRange(location: 0, length: sourceText.length))
    }

    private func replacingMentions(in source: String, from state: NormalizedState) -> String {
        let raw = source as NSString
        let matches = Self.mentionExpression.matches(
            in: source,
            options: [],
            range: NSRange(location: 0, length: raw.length)
        )

        guard !matches.isEmpty else {
            return source
        }

        let rendered = NSMutableString(string: source)
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else {
                continue
            }

            let idRange = match.range(at: 1)
            let identifier = raw.substring(with: idRange)
            guard let user = state.users[identifier] else {
                continue
            }

            rendered.replaceCharacters(in: match.range, with: "@\(user.displayName)")
        }

        return rendered as String
    }

    private func customEmojiURL(for identifier: String, animated: Bool) -> URL? {
        let format = animated ? "gif" : "png"
        return URL(
            string: "https://cdn.discordapp.com/emojis/\(identifier).\(format)?size=64&quality=lossless"
        )
    }

    private func normalizedTextLine(for source: String) -> NormalizedTextLine {
        let trimmedLeadingWhitespace = source.prefix { $0 == " " || $0 == "\t" }
        let withoutIndent = String(source.dropFirst(trimmedLeadingWhitespace.count))

        let paragraphStyle: MessageParagraphStyle
        let workingSource: String
        if withoutIndent.hasPrefix("- ") || withoutIndent.hasPrefix("* ") {
            paragraphStyle = .bullet
            workingSource = String(withoutIndent.dropFirst(2))
        } else {
            paragraphStyle = .normal
            workingSource = source
        }

        let sourceText = workingSource as NSString
        let matches = Self.autolinkExpression.matches(
            in: workingSource,
            range: NSRange(location: 0, length: sourceText.length)
        )

        guard !matches.isEmpty else {
            return NormalizedTextLine(
                visibleText: workingSource,
                paragraphStyle: paragraphStyle,
                suppressedPreviewURLs: []
            )
        }

        let rendered = NSMutableString(string: workingSource)
        var suppressedPreviewURLs: [String] = []
        for match in matches.reversed() where match.numberOfRanges > 1 {
            let enclosedURL = sourceText.substring(with: match.range(at: 1))
            rendered.replaceCharacters(in: match.range, with: enclosedURL)
            if let canonical = canonicalURL(for: enclosedURL)?.absoluteString {
                suppressedPreviewURLs.append(canonical)
            }
        }

        return NormalizedTextLine(
            visibleText: rendered as String,
            paragraphStyle: paragraphStyle,
            suppressedPreviewURLs: suppressedPreviewURLs.reversed()
        )
    }
}

private struct ParsedTextLine {
    var plainText: String
    var fragments: [MessageInlineFragment]
    var paragraphStyle: MessageParagraphStyle = .normal
    var suppressedPreviewURLs: [String] = []
}

private struct NormalizedTextLine {
    var visibleText: String
    var paragraphStyle: MessageParagraphStyle
    var suppressedPreviewURLs: [String]
}

private extension RelationshipKind {
    var sortIndex: Int {
        switch self {
        case .friend:
            return 0
        case .incomingRequest:
            return 1
        case .outgoingRequest:
            return 2
        case .implicit:
            return 3
        case .blocked:
            return 4
        }
    }
}

private extension DiscordChannelKind {
    var sortPriority: Int {
        switch self {
        case .guildCategory:
            return 0
        case .guildText, .guildNews, .guildForum, .guildMedia:
            return 1
        case .guildVoice, .guildStageVoice:
            return 2
        case .publicThread, .privateThread:
            return 3
        case .directMessage, .groupDM, .ephemeralDM, .lobby:
            return 4
        }
    }
}
