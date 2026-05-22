import Foundation

public enum DiscordChannelKind: Int, Codable, Sendable, Hashable, CaseIterable {
    case guildText = 0
    case directMessage = 1
    case guildVoice = 2
    case groupDM = 3
    case guildCategory = 4
    case guildNews = 5
    case publicThread = 11
    case privateThread = 12
    case guildStageVoice = 13
    case guildForum = 15
    case guildMedia = 16
    case lobby = 17
    case ephemeralDM = 18

    @inlinable
    public var supportsTimeline: Bool {
        switch self {
        case .guildText, .directMessage, .groupDM, .guildNews, .publicThread, .privateThread:
            true
        default:
            false
        }
    }
}

public struct DiscordUser: Codable, Hashable, Sendable {
    public var id: UserID
    public var username: String
    public var discriminator: String
    public var globalName: String?
    public var avatarHash: String?
    public var bannerHash: String?
    public var accentColor: Int?
    public var bot: Bool

    public init(
        id: UserID,
        username: String,
        discriminator: String = "0",
        globalName: String? = nil,
        avatarHash: String? = nil,
        bannerHash: String? = nil,
        accentColor: Int? = nil,
        bot: Bool = false
    ) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.globalName = globalName
        self.avatarHash = avatarHash
        self.bannerHash = bannerHash
        self.accentColor = accentColor
        self.bot = bot
    }

    public var displayName: String {
        globalName ?? username
    }

    public var tag: String {
        if discriminator == "0" {
            return "@\(username)"
        }
        return "\(username)#\(discriminator)"
    }

    public func merged(with incoming: DiscordUser) -> DiscordUser {
        DiscordUser(
            id: incoming.id,
            username: incoming.username.isEmpty ? username : incoming.username,
            discriminator: incoming.discriminator == "0" && discriminator != "0" ? discriminator : incoming.discriminator,
            globalName: incoming.globalName.normalized ?? globalName,
            avatarHash: incoming.avatarHash.normalized ?? avatarHash,
            bannerHash: incoming.bannerHash.normalized ?? bannerHash,
            accentColor: incoming.accentColor ?? accentColor,
            bot: bot || incoming.bot
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case discriminator
        case globalName
        case avatarHash
        case bannerHash
        case accentColor
        case bot
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UserID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        discriminator = try container.decodeIfPresent(String.self, forKey: .discriminator) ?? "0"
        globalName = try container.decodeIfPresent(String.self, forKey: .globalName)
        avatarHash = try container.decodeIfPresent(String.self, forKey: .avatarHash)
        bannerHash = try container.decodeIfPresent(String.self, forKey: .bannerHash)
        accentColor = try container.decodeIfPresent(Int.self, forKey: .accentColor)
        bot = try container.decodeIfPresent(Bool.self, forKey: .bot) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(discriminator, forKey: .discriminator)
        try container.encodeIfPresent(globalName, forKey: .globalName)
        try container.encodeIfPresent(avatarHash, forKey: .avatarHash)
        try container.encodeIfPresent(bannerHash, forKey: .bannerHash)
        try container.encodeIfPresent(accentColor, forKey: .accentColor)
        try container.encode(bot, forKey: .bot)
    }
}

public struct DiscordGuild: Codable, Hashable, Sendable {
    public var id: GuildID
    public var name: String
    public var unavailable: Bool
    public var version: Int?
    public var iconHash: String?
    public var bannerHash: String?
    public var ownerID: UserID?
    public var description: String?
    public var memberCount: Int?

    public init(
        id: GuildID,
        name: String,
        unavailable: Bool = false,
        version: Int? = nil,
        iconHash: String? = nil,
        bannerHash: String? = nil,
        ownerID: UserID? = nil,
        description: String? = nil,
        memberCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.unavailable = unavailable
        self.version = version
        self.iconHash = iconHash
        self.bannerHash = bannerHash
        self.ownerID = ownerID
        self.description = description
        self.memberCount = memberCount
    }

    public func merged(with incoming: DiscordGuild) -> DiscordGuild {
        DiscordGuild(
            id: incoming.id,
            name: incoming.name.isEmpty ? name : incoming.name,
            unavailable: incoming.unavailable,
            version: incoming.version ?? version,
            iconHash: incoming.iconHash.normalized ?? iconHash,
            bannerHash: incoming.bannerHash.normalized ?? bannerHash,
            ownerID: incoming.ownerID ?? ownerID,
            description: incoming.description.normalized ?? description,
            memberCount: incoming.memberCount ?? memberCount
        )
    }
}

public struct DiscordGuildMember: Codable, Hashable, Sendable {
    public var userID: UserID
    public var guildID: GuildID
    public var nickname: String?
    public var roleIDs: [RoleID]
    public var joinedAt: Date?
    public var deaf: Bool
    public var mute: Bool
    public var avatar: String?

    public init(
        userID: UserID,
        guildID: GuildID,
        nickname: String? = nil,
        roleIDs: [RoleID] = [],
        joinedAt: Date? = nil,
        deaf: Bool = false,
        mute: Bool = false,
        avatar: String? = nil
    ) {
        self.userID = userID
        self.guildID = guildID
        self.nickname = nickname
        self.roleIDs = roleIDs
        self.joinedAt = joinedAt
        self.deaf = deaf
        self.mute = mute
        self.avatar = avatar
    }
}

public struct DiscordGuildBan: Codable, Hashable, Sendable {
    public var userID: UserID
    public var reason: String?

    public init(userID: UserID, reason: String? = nil) {
        self.userID = userID
        self.reason = reason
    }
}

public struct DiscordGuildRole: Codable, Hashable, Sendable {
    public var id: RoleID
    public var guildID: GuildID
    public var name: String
    public var color: Int
    public var position: Int

    public init(
        id: RoleID,
        guildID: GuildID,
        name: String,
        color: Int,
        position: Int
    ) {
        self.id = id
        self.guildID = guildID
        self.name = name
        self.color = color
        self.position = position
    }
}

public struct DiscordChannel: Codable, Hashable, Sendable {
    public var id: ChannelID
    public var kind: DiscordChannelKind
    public var guildID: GuildID?
    public var parentID: ChannelID?
    public var name: String?
    public var lastMessageID: MessageID?
    public var recipientIDs: [UserID]
    public var iconHash: String?
    public var topic: String?
    public var position: Int?

    public init(
        id: ChannelID,
        kind: DiscordChannelKind,
        guildID: GuildID? = nil,
        parentID: ChannelID? = nil,
        name: String? = nil,
        lastMessageID: MessageID? = nil,
        recipientIDs: [UserID] = [],
        iconHash: String? = nil,
        topic: String? = nil,
        position: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.guildID = guildID
        self.parentID = parentID
        self.name = name
        self.lastMessageID = lastMessageID
        self.recipientIDs = recipientIDs
        self.iconHash = iconHash
        self.topic = topic
        self.position = position
    }


    public func merged(with incoming: DiscordChannel) -> DiscordChannel {
        DiscordChannel(
            id: incoming.id,
            kind: incoming.kind,
            guildID: incoming.guildID ?? guildID,
            parentID: incoming.parentID ?? parentID,
            name: incoming.name.normalized ?? name,
            lastMessageID: incoming.lastMessageID ?? lastMessageID,
            recipientIDs: incoming.recipientIDs.isEmpty ? recipientIDs : incoming.recipientIDs,
            iconHash: incoming.iconHash.normalized ?? iconHash,
            topic: incoming.topic.normalized ?? topic,
            position: incoming.position ?? position
        )
    }
}

public struct DiscordMessageAttachment: Codable, Hashable, Sendable {
    public var id: String
    public var filename: String
    public var contentType: String?
    public var url: String
    public var proxyURL: String?
    public var width: Int?
    public var height: Int?

    public init(
        id: String,
        filename: String,
        contentType: String? = nil,
        url: String,
        proxyURL: String? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.filename = filename
        self.contentType = contentType
        self.url = url
        self.proxyURL = proxyURL
        self.width = width
        self.height = height
    }
}

public struct DiscordMessageEmbed: Codable, Hashable, Sendable {
    public var type: String
    public var url: String?
    public var title: String?
    public var description: String?
    public var thumbnailURL: String?
    public var imageURL: String?
    public var videoURL: String?

    public init(
        type: String,
        url: String? = nil,
        title: String? = nil,
        description: String? = nil,
        thumbnailURL: String? = nil,
        imageURL: String? = nil,
        videoURL: String? = nil
    ) {
        self.type = type
        self.url = url
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.imageURL = imageURL
        self.videoURL = videoURL
    }
}

public struct DiscordMessageReference: Codable, Hashable, Sendable {
    public var messageID: MessageID?
    public var channelID: ChannelID
    public var guildID: GuildID?

    public init(
        messageID: MessageID? = nil,
        channelID: ChannelID,
        guildID: GuildID? = nil
    ) {
        self.messageID = messageID
        self.channelID = channelID
        self.guildID = guildID
    }
}

public struct DiscordReferencedMessage: Codable, Hashable, Sendable {
    public var id: MessageID
    public var channelID: ChannelID
    public var author: DiscordUser
    public var content: String
    public var attachments: [DiscordMessageAttachment]
    public var embeds: [DiscordMessageEmbed]

    public init(
        id: MessageID,
        channelID: ChannelID,
        author: DiscordUser,
        content: String,
        attachments: [DiscordMessageAttachment] = [],
        embeds: [DiscordMessageEmbed] = []
    ) {
        self.id = id
        self.channelID = channelID
        self.author = author
        self.content = content
        self.attachments = attachments
        self.embeds = embeds
    }
}

public enum DiscordMessageType: Int, Codable, Sendable, Hashable, CaseIterable {
    case `default` = 0
    case recipientAdd = 1
    case recipientRemove = 2
    case call = 3
    case channelNameChange = 4
    case channelIconChange = 5
    case channelPinnedMessage = 6
    case guildMemberJoin = 7
    case userPremiumGuildSubscription = 8
    case userPremiumGuildSubscriptionTier1 = 9
    case userPremiumGuildSubscriptionTier2 = 10
    case userPremiumGuildSubscriptionTier3 = 11
    case channelFollowAdd = 12
    case guildDiscoveryDisqualified = 14
    case guildDiscoveryRequalified = 15
    case reply = 19
    case chatInputCommand = 20
    case threadStarterMessage = 21
    case guildInviteReminder = 22
    case contextMenuCommand = 23
    case autoModerationAction = 24
    case roleSubscriptionPurchase = 25
    case interactionPremiumUpsell = 26
    case stageStart = 27
    case stageEnd = 28
    case stageSpeaker = 29
    case stageTopic = 31
    case guildApplicationPremiumSubscription = 32
}

public struct DiscordReactionEmoji: Codable, Hashable, Sendable {
    public var id: String?
    public var name: String
    public var animated: Bool

    public init(id: String? = nil, name: String, animated: Bool = false) {
        self.id = id
        self.name = name
        self.animated = animated
    }

    public var urlEncoded: String {
        if let id {
            return "\(name):\(id)"
        }
        return name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    }
}

public struct DiscordGuildEmoji: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var guildID: GuildID
    public var name: String
    public var animated: Bool

    public init(id: String, guildID: GuildID, name: String, animated: Bool = false) {
        self.id = id
        self.guildID = guildID
        self.name = name
        self.animated = animated
    }

    public var reactionEmoji: DiscordReactionEmoji {
        DiscordReactionEmoji(id: id, name: name, animated: animated)
    }

    public var imageURL: URL? {
        URL(string: "https://cdn.discordapp.com/emojis/\(id).\(animated ? "gif" : "png")?size=64&quality=lossless")
    }
}

public struct DiscordReactionCountDetails: Codable, Hashable, Sendable {
    public var burst: Int
    public var normal: Int

    public init(burst: Int = 0, normal: Int = 0) {
        self.burst = burst
        self.normal = normal
    }
}

public struct DiscordMessageReaction: Codable, Hashable, Sendable {
    public var emoji: DiscordReactionEmoji
    public var count: Int
    public var countDetails: DiscordReactionCountDetails
    public var me: Bool
    public var meBurst: Bool

    public init(
        emoji: DiscordReactionEmoji,
        count: Int,
        countDetails: DiscordReactionCountDetails = .init(),
        me: Bool = false,
        meBurst: Bool = false
    ) {
        self.emoji = emoji
        self.count = count
        self.countDetails = countDetails
        self.me = me
        self.meBurst = meBurst
    }
}

public struct DiscordMessageSearchResults: Hashable, Sendable {
    public var totalResults: Int
    public var messages: [DiscordMessage]

    public init(totalResults: Int, messages: [DiscordMessage]) {
        self.totalResults = totalResults
        self.messages = messages
    }
}

public struct DiscordMessage: Codable, Hashable, Sendable {
    public var id: MessageID
    public var channelID: ChannelID
    public var authorID: UserID
    public var content: String
    public var timestamp: Date
    public var editedTimestamp: Date?
    public var flags: MessageFlags
    public var memberNickname: String?
    public var memberRoleIDs: [RoleID]
    public var attachments: [DiscordMessageAttachment]
    public var embeds: [DiscordMessageEmbed]
    public var messageReference: DiscordMessageReference?
    public var referencedMessage: DiscordReferencedMessage?
    public var didLoadReferencedMessage: Bool
    public var type: DiscordMessageType
    public var pinned: Bool
    public var reactions: [DiscordMessageReaction]

    public init(
        id: MessageID,
        channelID: ChannelID,
        authorID: UserID,
        content: String,
        timestamp: Date,
        editedTimestamp: Date? = nil,
        flags: MessageFlags = [],
        memberNickname: String? = nil,
        memberRoleIDs: [RoleID] = [],
        attachments: [DiscordMessageAttachment] = [],
        embeds: [DiscordMessageEmbed] = [],
        messageReference: DiscordMessageReference? = nil,
        referencedMessage: DiscordReferencedMessage? = nil,
        didLoadReferencedMessage: Bool = false,
        type: DiscordMessageType = .default,
        pinned: Bool = false,
        reactions: [DiscordMessageReaction] = []
    ) {
        self.id = id
        self.channelID = channelID
        self.authorID = authorID
        self.content = content
        self.timestamp = timestamp
        self.editedTimestamp = editedTimestamp
        self.flags = flags
        self.memberNickname = memberNickname
        self.memberRoleIDs = memberRoleIDs
        self.attachments = attachments
        self.embeds = embeds
        self.messageReference = messageReference
        self.referencedMessage = referencedMessage
        self.didLoadReferencedMessage = didLoadReferencedMessage
        self.type = type
        self.pinned = pinned
        self.reactions = reactions
    }

    enum CodingKeys: String, CodingKey {
        case id
        case channelID
        case authorID
        case content
        case timestamp
        case editedTimestamp
        case flags
        case memberNickname
        case memberRoleIDs
        case attachments
        case embeds
        case messageReference
        case referencedMessage
        case didLoadReferencedMessage
        case type
        case pinned
        case reactions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MessageID.self, forKey: .id)
        channelID = try container.decode(ChannelID.self, forKey: .channelID)
        authorID = try container.decode(UserID.self, forKey: .authorID)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        editedTimestamp = try container.decodeIfPresent(Date.self, forKey: .editedTimestamp)
        flags = try container.decodeIfPresent(MessageFlags.self, forKey: .flags) ?? []
        memberNickname = try container.decodeIfPresent(String.self, forKey: .memberNickname)
        memberRoleIDs = try container.decodeIfPresent([RoleID].self, forKey: .memberRoleIDs) ?? []
        attachments = try container.decodeIfPresent([DiscordMessageAttachment].self, forKey: .attachments) ?? []
        embeds = try container.decodeIfPresent([DiscordMessageEmbed].self, forKey: .embeds) ?? []
        messageReference = try container.decodeIfPresent(DiscordMessageReference.self, forKey: .messageReference)
        referencedMessage = try container.decodeIfPresent(DiscordReferencedMessage.self, forKey: .referencedMessage)
        didLoadReferencedMessage = try container.decodeIfPresent(Bool.self, forKey: .didLoadReferencedMessage) ?? false
        type = try container.decodeIfPresent(DiscordMessageType.self, forKey: .type) ?? .default
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        reactions = try container.decodeIfPresent([DiscordMessageReaction].self, forKey: .reactions) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(channelID, forKey: .channelID)
        try container.encode(authorID, forKey: .authorID)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(editedTimestamp, forKey: .editedTimestamp)
        try container.encode(flags, forKey: .flags)
        try container.encodeIfPresent(memberNickname, forKey: .memberNickname)
        try container.encode(memberRoleIDs, forKey: .memberRoleIDs)
        try container.encode(attachments, forKey: .attachments)
        try container.encode(embeds, forKey: .embeds)
        try container.encodeIfPresent(messageReference, forKey: .messageReference)
        try container.encodeIfPresent(referencedMessage, forKey: .referencedMessage)
        try container.encode(didLoadReferencedMessage, forKey: .didLoadReferencedMessage)
        try container.encode(type, forKey: .type)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(reactions, forKey: .reactions)
    }
}

public enum RelationshipKind: String, Codable, Sendable, Hashable, CaseIterable {
    case friend
    case blocked
    case incomingRequest
    case outgoingRequest
    case implicit
}

public struct DiscordRelationship: Codable, Hashable, Sendable {
    public var userID: UserID
    public var kind: RelationshipKind
    public var nickname: String?

    public init(userID: UserID, kind: RelationshipKind, nickname: String? = nil) {
        self.userID = userID
        self.kind = kind
        self.nickname = nickname
    }
}

public struct DiscordMutualGuild: Codable, Hashable, Sendable {
    public var guildID: GuildID
    public var nickname: String?

    public init(guildID: GuildID, nickname: String? = nil) {
        self.guildID = guildID
        self.nickname = nickname
    }
}

public struct DiscordUserProfile: Codable, Hashable, Sendable {
    public var userID: UserID
    public var bio: String?
    public var pronouns: String?
    public var bannerHash: String?
    public var accentColor: Int?
    public var themeColors: [Int]
    public var premiumType: Int?
    public var mutualGuilds: [DiscordMutualGuild]
    public var mutualFriendIDs: [UserID]
    public var guildMember: DiscordGuildMemberProfile?

    public init(
        userID: UserID,
        bio: String? = nil,
        pronouns: String? = nil,
        bannerHash: String? = nil,
        accentColor: Int? = nil,
        themeColors: [Int] = [],
        premiumType: Int? = nil,
        mutualGuilds: [DiscordMutualGuild] = [],
        mutualFriendIDs: [UserID] = [],
        guildMember: DiscordGuildMemberProfile? = nil
    ) {
        self.userID = userID
        self.bio = bio
        self.pronouns = pronouns
        self.bannerHash = bannerHash
        self.accentColor = accentColor
        self.themeColors = themeColors
        self.premiumType = premiumType
        self.mutualGuilds = mutualGuilds
        self.mutualFriendIDs = mutualFriendIDs
        self.guildMember = guildMember
    }

    public func merged(with incoming: DiscordUserProfile) -> DiscordUserProfile {
        DiscordUserProfile(
            userID: incoming.userID,
            bio: incoming.bio.normalized ?? bio,
            pronouns: incoming.pronouns.normalized ?? pronouns,
            bannerHash: incoming.bannerHash.normalized ?? bannerHash,
            accentColor: incoming.accentColor ?? accentColor,
            themeColors: incoming.themeColors.isEmpty ? themeColors : incoming.themeColors,
            premiumType: incoming.premiumType ?? premiumType,
            mutualGuilds: incoming.mutualGuilds.isEmpty ? mutualGuilds : incoming.mutualGuilds,
            mutualFriendIDs: incoming.mutualFriendIDs.isEmpty ? mutualFriendIDs : incoming.mutualFriendIDs,
            guildMember: incoming.guildMember ?? guildMember
        )
    }
}

public struct DiscordGuildMemberProfile: Codable, Hashable, Sendable {
    public var guildID: GuildID
    public var nickname: String?
    public var roleIDs: [RoleID]

    public init(
        guildID: GuildID,
        nickname: String? = nil,
        roleIDs: [RoleID] = []
    ) {
        self.guildID = guildID
        self.nickname = nickname
        self.roleIDs = roleIDs
    }
}

public enum PresenceStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case online
    case idle
    case dnd
    case invisible
    case offline
    case unknown
}

public struct DiscordPresence: Codable, Hashable, Sendable {
    public var userID: UserID
    public var status: PresenceStatus

    public init(userID: UserID, status: PresenceStatus) {
        self.userID = userID
        self.status = status
    }
}

public struct DiscordReadState: Codable, Hashable, Sendable {
    public var channelID: ChannelID
    public var lastMessageID: MessageID
    public var mentionCount: Int
    public var version: Int

    public init(channelID: ChannelID, lastMessageID: MessageID, mentionCount: Int = 0, version: Int = 0) {
        self.channelID = channelID
        self.lastMessageID = lastMessageID
        self.mentionCount = mentionCount
        self.version = version
    }
}

public struct DiscordUserSettings: Codable, Hashable, Sendable {
    public var locale: String
    public var theme: String

    public init(locale: String, theme: String) {
        self.locale = locale
        self.theme = theme
    }
}

public struct DiscordNotificationSettings: Codable, Hashable, Sendable {
    public var mutedChannelIDs: [ChannelID]

    public init(mutedChannelIDs: [ChannelID] = []) {
        self.mutedChannelIDs = mutedChannelIDs
    }
}

public struct DiscordUserNote: Codable, Hashable, Sendable {
    public var userID: UserID
    public var note: String

    public init(userID: UserID, note: String) {
        self.userID = userID
        self.note = note
    }
}

public struct DiscordInvite: Codable, Hashable, Sendable {
    public var code: String
    public var guildID: GuildID?
    public var guildName: String?
    public var guildIconHash: String?
    public var channelID: ChannelID?
    public var channelName: String?
    public var memberCount: Int?
    public var onlineCount: Int?
    public var expiresAt: Date?

    public init(
        code: String,
        guildID: GuildID? = nil,
        guildName: String? = nil,
        guildIconHash: String? = nil,
        channelID: ChannelID? = nil,
        channelName: String? = nil,
        memberCount: Int? = nil,
        onlineCount: Int? = nil,
        expiresAt: Date? = nil
    ) {
        self.code = code
        self.guildID = guildID
        self.guildName = guildName
        self.guildIconHash = guildIconHash
        self.channelID = channelID
        self.channelName = channelName
        self.memberCount = memberCount
        self.onlineCount = onlineCount
        self.expiresAt = expiresAt
    }
}

public extension Optional where Wrapped == String {
    var normalized: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
