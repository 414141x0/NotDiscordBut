import Foundation
import DiscordPrimitives
import DiscordState

public struct MessageReferenceSendInput: Hashable, Sendable {
    public var messageID: MessageID
    public var channelID: ChannelID
    public var guildID: GuildID?

    public init(
        messageID: MessageID,
        channelID: ChannelID,
        guildID: GuildID? = nil
    ) {
        self.messageID = messageID
        self.channelID = channelID
        self.guildID = guildID
    }
}

public struct MessageAttachmentInput: Sendable {
    public var id: Int
    public var filename: String
    public var data: Data
    public var contentType: String

    public init(id: Int, filename: String, data: Data, contentType: String) {
        self.id = id
        self.filename = filename
        self.data = data
        self.contentType = contentType
    }
}

public struct MessageSendInput: Sendable {
    public var channelID: ChannelID
    public var content: String
    public var nonce: MessageNonce?
    public var messageReference: MessageReferenceSendInput?
    public var attachments: [MessageAttachmentInput]

    public init(
        channelID: ChannelID,
        content: String,
        nonce: MessageNonce? = nil,
        messageReference: MessageReferenceSendInput? = nil,
        attachments: [MessageAttachmentInput] = []
    ) {
        self.channelID = channelID
        self.content = content
        self.nonce = nonce
        self.messageReference = messageReference
        self.attachments = attachments
    }
}

public struct MessageEditInput: Hashable, Sendable {
    public var channelID: ChannelID
    public var messageID: MessageID
    public var content: String

    public init(channelID: ChannelID, messageID: MessageID, content: String) {
        self.channelID = channelID
        self.messageID = messageID
        self.content = content
    }
}

public struct ReactionInput: Hashable, Sendable {
    public var channelID: ChannelID
    public var messageID: MessageID
    public var emoji: DiscordReactionEmoji

    public init(channelID: ChannelID, messageID: MessageID, emoji: DiscordReactionEmoji) {
        self.channelID = channelID
        self.messageID = messageID
        self.emoji = emoji
    }
}

public struct ChannelEditInput: Hashable, Sendable {
    public var channelID: ChannelID
    public var name: String?
    public var topic: String?
    public var nsfw: Bool?
    public var rateLimitPerUser: Int?

    public init(
        channelID: ChannelID,
        name: String? = nil,
        topic: String? = nil,
        nsfw: Bool? = nil,
        rateLimitPerUser: Int? = nil
    ) {
        self.channelID = channelID
        self.name = name
        self.topic = topic
        self.nsfw = nsfw
        self.rateLimitPerUser = rateLimitPerUser
    }
}

public struct GuildMemberModifyInput: Hashable, Sendable {
    public var guildID: GuildID
    public var userID: UserID
    public var nickname: String?
    public var roleIDs: [RoleID]?
    public var mute: Bool?
    public var deaf: Bool?

    public init(
        guildID: GuildID,
        userID: UserID,
        nickname: String? = nil,
        roleIDs: [RoleID]? = nil,
        mute: Bool? = nil,
        deaf: Bool? = nil
    ) {
        self.guildID = guildID
        self.userID = userID
        self.nickname = nickname
        self.roleIDs = roleIDs
        self.mute = mute
        self.deaf = deaf
    }
}

public struct GuildBanInput: Hashable, Sendable {
    public var guildID: GuildID
    public var userID: UserID
    public var deleteMessageSeconds: Int?

    public init(guildID: GuildID, userID: UserID, deleteMessageSeconds: Int? = nil) {
        self.guildID = guildID
        self.userID = userID
        self.deleteMessageSeconds = deleteMessageSeconds
    }
}

public struct GuildModifyInput: Hashable, Sendable {
    public var guildID: GuildID
    public var name: String?
    public var description: String?

    public init(guildID: GuildID, name: String? = nil, description: String? = nil) {
        self.guildID = guildID
        self.name = name
        self.description = description
    }
}

public struct NotificationBadgeSnapshot: Hashable, Sendable {
    public var unreadChannelCount: Int
    public var pendingMessageCount: Int

    public init(unreadChannelCount: Int, pendingMessageCount: Int) {
        self.unreadChannelCount = unreadChannelCount
        self.pendingMessageCount = pendingMessageCount
    }
}

public typealias DiscordSidebarProjection = SidebarProjection
public typealias DiscordChannelListProjection = ChannelListProjection
public typealias DiscordTimelineProjection = TimelineProjection
