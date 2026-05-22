import Foundation
import DiscordHTTP
import DiscordPrimitives

struct APIUserDTO: Decodable, Sendable {
    var id: UserID
    var username: String
    var discriminator: String?
    var globalName: String?
    var avatar: String?
    var banner: String?
    var accentColor: Int?
    var bot: Bool?
    var bio: String?

    func toDomain() -> DiscordUser {
        DiscordUser(
            id: id,
            username: username,
            discriminator: discriminator ?? "0",
            globalName: globalName,
            avatarHash: avatar,
            bannerHash: banner,
            accentColor: accentColor,
            bot: bot ?? false
        )
    }
}

struct APIGuildDTO: Decodable, Sendable {
    var id: GuildID
    var name: String
    var unavailable: Bool?
    var icon: String?
    var banner: String?

    func toDomain() -> DiscordGuild {
        DiscordGuild(
            id: id,
            name: name,
            unavailable: unavailable ?? false,
            iconHash: icon,
            bannerHash: banner
        )
    }
}

struct APIGuildRoleDTO: Decodable, Sendable {
    var id: RoleID
    var name: String
    var color: Int
    var position: Int

    func toDomain(guildID: GuildID) -> DiscordGuildRole {
        DiscordGuildRole(
            id: id,
            guildID: guildID,
            name: name,
            color: color,
            position: position
        )
    }
}

struct APIGuildEmojiDTO: Decodable, Sendable {
    var id: String
    var name: String
    var animated: Bool?

    func toDomain(guildID: GuildID) -> DiscordGuildEmoji {
        DiscordGuildEmoji(
            id: id,
            guildID: guildID,
            name: name,
            animated: animated ?? false
        )
    }
}

struct APIRelationshipDTO: Decodable, Sendable {
    var id: UserID
    var type: Int
    var user: APIUserDTO
    var nickname: String?

    func toDomain() -> DiscordRelationship? {
        guard let kind = RelationshipKind(apiValue: type) else {
            return nil
        }

        return DiscordRelationship(
            userID: id,
            kind: kind,
            nickname: nickname
        )
    }
}

struct APIChannelDTO: Decodable, Sendable {
    var id: ChannelID
    var type: Int
    var guildId: GuildID?
    var parentId: ChannelID?
    var name: String?
    var lastMessageId: MessageID?
    var recipients: [APIUserDTO]?
    var icon: String?
    var topic: String?
    var position: Int?

    func toDomain(currentUserID: UserID?) -> (channel: DiscordChannel, users: [DiscordUser])? {
        guard let kind = DiscordChannelKind(rawValue: type) else {
            return nil
        }

        let users = recipients?.map { $0.toDomain() } ?? []
        let recipientIDs = users.map(\.id).filter { $0 != currentUserID }

        let resolvedName: String?
        switch kind {
        case .directMessage:
            resolvedName = users.first.map { $0.globalName ?? $0.username }
        case .groupDM:
            if let name, !name.isEmpty {
                resolvedName = name
            } else {
                let participantNames = users.map { $0.globalName ?? $0.username }
                resolvedName = participantNames.isEmpty ? nil : participantNames.joined(separator: ", ")
            }
        default:
            resolvedName = name
        }

        return (
            DiscordChannel(
                id: id,
                kind: kind,
                guildID: guildId,
                parentID: parentId,
                name: resolvedName,
                lastMessageID: lastMessageId,
                recipientIDs: recipientIDs,
                iconHash: icon,
                topic: topic,
                position: position
            ),
            users
        )
    }
}

struct APIReactionDTO: Decodable, Sendable {
    struct EmojiDTO: Decodable, Sendable {
        var id: String?
        var name: String?
        var animated: Bool?

        func toDomain() -> DiscordReactionEmoji {
            DiscordReactionEmoji(id: id, name: name ?? "?", animated: animated ?? false)
        }
    }

    struct CountDetailsDTO: Decodable, Sendable {
        var burst: Int?
        var normal: Int?

        func toDomain() -> DiscordReactionCountDetails {
            DiscordReactionCountDetails(burst: burst ?? 0, normal: normal ?? 0)
        }
    }

    var emoji: EmojiDTO
    var count: Int
    var countDetails: CountDetailsDTO?
    var me: Bool?
    var meBurst: Bool?

    func toDomain() -> DiscordMessageReaction {
        DiscordMessageReaction(
            emoji: emoji.toDomain(),
            count: count,
            countDetails: countDetails?.toDomain() ?? .init(),
            me: me ?? false,
            meBurst: meBurst ?? false
        )
    }
}

struct APIMessageDTO: Decodable, Sendable {
    struct MessageReferenceDTO: Decodable, Sendable {
        var messageId: MessageID?
        var channelId: ChannelID
        var guildId: GuildID?

        func toDomain() -> DiscordMessageReference {
            DiscordMessageReference(
                messageID: messageId,
                channelID: channelId,
                guildID: guildId
            )
        }
    }

    struct ReferencedMessageDTO: Decodable, Sendable {
        var id: MessageID
        var channelId: ChannelID
        var author: APIUserDTO
        var content: String
        var attachments: [APIAttachmentDTO]?
        var embeds: [APIEmbedDTO]?

        func toDomain() -> (message: DiscordReferencedMessage, users: [DiscordUser]) {
            let authorUser = author.toDomain()
            return (
                DiscordReferencedMessage(
                    id: id,
                    channelID: channelId,
                    author: authorUser,
                    content: content,
                    attachments: attachments?.map { $0.toDomain() } ?? [],
                    embeds: embeds?.compactMap { $0.toDomain() } ?? []
                ),
                [authorUser]
            )
        }
    }

    var id: MessageID
    var channelId: ChannelID
    var author: APIUserDTO
    var member: APIGuildMemberMessageDTO?
    var content: String
    var timestamp: Date
    var editedTimestamp: Date?
    var flags: Int?
    var attachments: [APIAttachmentDTO]?
    var embeds: [APIEmbedDTO]?
    var mentions: [APIUserDTO]?
    var messageReference: MessageReferenceDTO?
    var referencedMessage: ReferencedMessageDTO?
    var didLoadReferencedMessage: Bool
    var type: Int?
    var pinned: Bool?
    var reactions: [APIReactionDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case channelId
        case author
        case member
        case content
        case timestamp
        case editedTimestamp
        case flags
        case attachments
        case embeds
        case mentions
        case messageReference
        case referencedMessage
        case type
        case pinned
        case reactions
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MessageID.self, forKey: .id)
        channelId = try container.decode(ChannelID.self, forKey: .channelId)
        author = try container.decode(APIUserDTO.self, forKey: .author)
        member = try container.decodeIfPresent(APIGuildMemberMessageDTO.self, forKey: .member)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        editedTimestamp = try container.decodeIfPresent(Date.self, forKey: .editedTimestamp)
        flags = try container.decodeIfPresent(Int.self, forKey: .flags)
        attachments = try container.decodeIfPresent([APIAttachmentDTO].self, forKey: .attachments)
        embeds = try container.decodeIfPresent([APIEmbedDTO].self, forKey: .embeds)
        mentions = try container.decodeIfPresent([APIUserDTO].self, forKey: .mentions)
        messageReference = try container.decodeIfPresent(MessageReferenceDTO.self, forKey: .messageReference)
        didLoadReferencedMessage = container.contains(.referencedMessage)
        referencedMessage = try container.decodeIfPresent(ReferencedMessageDTO.self, forKey: .referencedMessage)
        type = try container.decodeIfPresent(Int.self, forKey: .type)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned)
        reactions = try container.decodeIfPresent([APIReactionDTO].self, forKey: .reactions)
    }

    func toDomain() -> (message: DiscordMessage, users: [DiscordUser]) {
        let authorUser = author.toDomain()
        let mentionedUsers = mentions?.map { $0.toDomain() } ?? []
        let referenced = referencedMessage?.toDomain()
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
                attachments: attachments?.map { $0.toDomain() } ?? [],
                embeds: embeds?.compactMap { $0.toDomain() } ?? [],
                messageReference: messageReference?.toDomain(),
                referencedMessage: referenced?.message,
                didLoadReferencedMessage: didLoadReferencedMessage,
                type: type.flatMap(DiscordMessageType.init(rawValue:)) ?? .default,
                pinned: pinned ?? false,
                reactions: reactions?.map { $0.toDomain() } ?? []
            ),
            [authorUser] + mentionedUsers + (referenced?.users ?? [])
        )
    }
}

struct APIGuildMemberMessageDTO: Decodable, Sendable {
    var nick: String?
    var roles: [RoleID]?
}

struct APIAttachmentDTO: Decodable, Sendable {
    var id: String
    var filename: String
    var contentType: String?
    var url: String
    var proxyUrl: String?
    var width: Int?
    var height: Int?

    func toDomain() -> DiscordMessageAttachment {
        DiscordMessageAttachment(
            id: id,
            filename: filename,
            contentType: contentType,
            url: url,
            proxyURL: proxyUrl,
            width: width,
            height: height
        )
    }
}

struct APIEmbedDTO: Decodable, Sendable {
    struct ImageResource: Decodable, Sendable {
        var url: String?
    }

    var type: String?
    var url: String?
    var title: String?
    var description: String?
    var thumbnail: ImageResource?
    var image: ImageResource?
    var video: ImageResource?

    func toDomain() -> DiscordMessageEmbed? {
        guard type != nil || url != nil || title != nil || description != nil else {
            return nil
        }

        return DiscordMessageEmbed(
            type: type ?? "rich",
            url: url,
            title: title,
            description: description,
            thumbnailURL: thumbnail?.url,
            imageURL: image?.url,
            videoURL: video?.url
        )
    }
}

struct APIUserProfileResponseDTO: Decodable, Sendable {
    var user: APIUserDTO
    var userProfile: APIProfileMetadataDTO?
    var guildMember: APIGuildMemberProfileDTO?
    var mutualGuilds: [APIMutualGuildDTO]?
    var mutualFriends: [APIUserDTO]?
    var premiumType: Int?

    func toUserProfile(guildID: GuildID? = nil) -> DiscordUserProfile {
        let resolvedAccentColor = userProfile?.accentColor ?? user.accentColor
        let resolvedBannerHash = userProfile?.banner ?? user.banner

        return DiscordUserProfile(
            userID: user.id,
            bio: userProfile?.bio ?? user.bio,
            pronouns: userProfile?.pronouns,
            bannerHash: resolvedBannerHash,
            accentColor: resolvedAccentColor,
            themeColors: userProfile?.themeColors ?? [],
            premiumType: premiumType,
            mutualGuilds: mutualGuilds?.map { $0.toDomain() } ?? [],
            mutualFriendIDs: mutualFriends?.map(\.id) ?? [],
            guildMember: guildMember?.toDomain(guildID: guildID)
        )
    }
}

struct APIGuildMemberProfileDTO: Decodable, Sendable {
    var nick: String?
    var roles: [RoleID]?

    func toDomain(guildID: GuildID?) -> DiscordGuildMemberProfile? {
        guard let guildID else {
            return nil
        }
        return DiscordGuildMemberProfile(
            guildID: guildID,
            nickname: nick,
            roleIDs: roles ?? []
        )
    }
}

struct APIProfileMetadataDTO: Decodable, Sendable {
    var bio: String?
    var pronouns: String?
    var banner: String?
    var accentColor: Int?
    var themeColors: [Int]?
}

struct APIMutualGuildDTO: Decodable, Sendable {
    var id: GuildID
    var nick: String?

    func toDomain() -> DiscordMutualGuild {
        DiscordMutualGuild(guildID: id, nickname: nick)
    }
}

extension RelationshipKind {
    init?(apiValue: Int) {
        switch apiValue {
        case 1:
            self = .friend
        case 2:
            self = .blocked
        case 3:
            self = .incomingRequest
        case 4:
            self = .outgoingRequest
        case 5:
            self = .implicit
        default:
            return nil
        }
    }
}
