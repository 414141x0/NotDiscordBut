import Foundation
import DiscordPrimitives

public struct GatewayMessageCreateDTO: Decodable, Sendable {
    public var id: MessageID
    public var channelId: ChannelID
    public var author: GatewayUserDTO
    public var member: GatewayMemberDTO?
    public var content: String
    public var timestamp: Date
    public var editedTimestamp: Date?
    public var flags: Int?
    public var type: Int?
    public var pinned: Bool?

    enum CodingKeys: String, CodingKey {
        case id, channelId, author, member, content, timestamp, editedTimestamp, flags, type, pinned
    }

    public func toDomain() -> (message: DiscordMessage, users: [DiscordUser]) {
        let user = author.toDomain()
        return (
            DiscordMessage(
                id: id,
                channelID: channelId,
                authorID: author.id,
                content: content,
                timestamp: timestamp,
                editedTimestamp: editedTimestamp,
                flags: MessageFlags(rawValue: flags ?? 0),
                memberNickname: member?.nick,
                memberRoleIDs: member?.roles ?? [],
                type: type.flatMap(DiscordMessageType.init(rawValue:)) ?? .default,
                pinned: pinned ?? false
            ),
            [user]
        )
    }
}

public struct GatewayUserDTO: Decodable, Sendable {
    public var id: UserID
    public var username: String
    public var discriminator: String?
    public var globalName: String?
    public var avatar: String?
    public var bot: Bool?

    public func toDomain() -> DiscordUser {
        DiscordUser(
            id: id,
            username: username,
            discriminator: discriminator ?? "0",
            globalName: globalName,
            avatarHash: avatar,
            bot: bot ?? false
        )
    }
}

public struct GatewayMemberDTO: Decodable, Sendable {
    public var nick: String?
    public var roles: [RoleID]?
}

public struct GatewayMessageDeleteDTO: Decodable, Sendable {
    public var id: MessageID
    public var channelId: ChannelID
    public var guildId: GuildID?

    public func toDomain() -> GatewayMessageDelete {
        GatewayMessageDelete(channelID: channelId, messageID: id, guildID: guildId)
    }
}

public struct GatewayTypingStartDTO: Decodable, Sendable {
    public var channelId: ChannelID
    public var userId: UserID
    public var guildId: GuildID?
    public var timestamp: Int

    public func toDomain() -> GatewayTypingStart {
        GatewayTypingStart(
            channelID: channelId,
            userID: userId,
            guildID: guildId,
            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp))
        )
    }
}

public struct GatewayChannelDTO: Decodable, Sendable {
    public var id: ChannelID
    public var type: Int
    public var guildId: GuildID?
    public var parentId: ChannelID?
    public var name: String?
    public var lastMessageId: MessageID?
    public var topic: String?
    public var position: Int?

    public func toDomain() -> DiscordChannel? {
        guard let kind = DiscordChannelKind(rawValue: type) else { return nil }
        return DiscordChannel(
            id: id,
            kind: kind,
            guildID: guildId,
            parentID: parentId,
            name: name,
            lastMessageID: lastMessageId,
            topic: topic,
            position: position
        )
    }
}

public struct GatewayPresenceUpdateDTO: Decodable, Sendable {
    public var user: GatewayPartialUserDTO
    public var status: String?

    public struct GatewayPartialUserDTO: Decodable, Sendable {
        public var id: UserID
    }

    public func toDomain() -> DiscordPresence {
        let resolvedStatus = PresenceStatus(rawValue: status ?? "offline") ?? .unknown
        return DiscordPresence(userID: user.id, status: resolvedStatus)
    }
}

public struct GatewayRelationshipAddDTO: Decodable, Sendable {
    public var id: UserID
    public var type: Int
    public var user: GatewayUserDTO
    public var nickname: String?

    public func toDomain() -> (relationship: DiscordRelationship, user: DiscordUser)? {
        guard let kind = RelationshipKind(apiValue: type) else { return nil }
        return (
            DiscordRelationship(userID: id, kind: kind, nickname: nickname),
            user.toDomain()
        )
    }
}

public struct GatewayRelationshipRemoveDTO: Decodable, Sendable {
    public var id: UserID
}

public struct GatewayReactionUpdateDTO: Decodable, Sendable {
    public var channelId: ChannelID
    public var messageId: MessageID
    public var userId: UserID
    public var guildId: GuildID?
    public var emoji: GatewayEmojiDTO

    public struct GatewayEmojiDTO: Decodable, Sendable {
        public var id: String?
        public var name: String?
        public var animated: Bool?

        public func toDomain() -> DiscordReactionEmoji {
            DiscordReactionEmoji(id: id, name: name ?? "?", animated: animated ?? false)
        }
    }

    public func toDomain() -> GatewayReactionUpdate {
        GatewayReactionUpdate(
            channelID: channelId,
            messageID: messageId,
            userID: userId,
            guildID: guildId,
            emoji: emoji.toDomain()
        )
    }
}

public struct GatewayGuildMemberAddDTO: Decodable, Sendable {
    public var guildId: GuildID
    public var user: GatewayUserDTO
    public var nick: String?
    public var roles: [RoleID]?
    public var joinedAt: Date?
    public var deaf: Bool?
    public var mute: Bool?

    public func toDomain() -> (member: DiscordGuildMember, user: DiscordUser) {
        (
            DiscordGuildMember(
                userID: user.id,
                guildID: guildId,
                nickname: nick,
                roleIDs: roles ?? [],
                joinedAt: joinedAt,
                deaf: deaf ?? false,
                mute: mute ?? false
            ),
            user.toDomain()
        )
    }
}

public struct GatewayGuildMemberUpdateDTO: Decodable, Sendable {
    public var guildId: GuildID
    public var user: GatewayUserDTO
    public var nick: String?
    public var roles: [RoleID]?
    public var joinedAt: Date?

    public func toDomain() -> DiscordGuildMember {
        DiscordGuildMember(
            userID: user.id,
            guildID: guildId,
            nickname: nick,
            roleIDs: roles ?? [],
            joinedAt: joinedAt
        )
    }
}

public struct GatewayGuildMemberRemoveDTO: Decodable, Sendable {
    public var guildId: GuildID
    public var user: GatewayUserDTO

    public func toDomain() -> GatewayGuildMemberRemove {
        GatewayGuildMemberRemove(guildID: guildId, userID: user.id)
    }
}

extension RelationshipKind {
    public init?(apiValue: Int) {
        switch apiValue {
        case 1: self = .friend
        case 2: self = .blocked
        case 3: self = .incomingRequest
        case 4: self = .outgoingRequest
        case 5: self = .implicit
        default: return nil
        }
    }
}
