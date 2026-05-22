import Foundation
import DiscordPrimitives

struct DiscordFeatureUserDTO: Decodable, Sendable {
    var id: UserID
    var username: String
    var discriminator: String?
    var globalName: String?
    var avatar: String?
    var banner: String?
    var accentColor: Int?
    var bot: Bool?

    func toDomain() -> DiscordUser {
        DiscordUser(
            id: id,
            username: username,
            discriminator: discriminator ?? "0",
            globalName: globalName.normalized,
            avatarHash: avatar.normalized,
            bannerHash: banner.normalized,
            accentColor: accentColor,
            bot: bot ?? false
        )
    }
}

struct DiscordFeatureChannelDTO: Decodable, Sendable {
    var id: ChannelID
    var type: Int
    var guildId: GuildID?
    var parentId: ChannelID?
    var name: String?
    var lastMessageId: MessageID?
    var recipients: [DiscordFeatureUserDTO]?
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
            resolvedName = users.first(where: { $0.id != currentUserID })?.displayName ?? name.normalized
        case .groupDM:
            if let resolved = name.normalized {
                resolvedName = resolved
            } else {
                let participantNames = users.map(\.displayName)
                resolvedName = participantNames.isEmpty ? nil : participantNames.joined(separator: ", ")
            }
        default:
            resolvedName = name.normalized
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
                iconHash: icon.normalized,
                topic: topic.normalized,
                position: position
            ),
            users
        )
    }
}

struct DiscordFeatureReactionDTO: Decodable, Sendable {
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

struct DiscordFeatureMessageDTO: Decodable, Sendable {
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
        var author: DiscordFeatureUserDTO
        var content: String
        var attachments: [DiscordFeatureAttachmentDTO]?
        var embeds: [DiscordFeatureEmbedDTO]?

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
    var author: DiscordFeatureUserDTO
    var member: DiscordFeatureGuildMemberDTO?
    var content: String
    var timestamp: Date
    var editedTimestamp: Date?
    var flags: Int?
    var attachments: [DiscordFeatureAttachmentDTO]?
    var embeds: [DiscordFeatureEmbedDTO]?
    var mentions: [DiscordFeatureUserDTO]?
    var messageReference: MessageReferenceDTO?
    var referencedMessage: ReferencedMessageDTO?
    var didLoadReferencedMessage: Bool
    var type: Int?
    var pinned: Bool?
    var reactions: [DiscordFeatureReactionDTO]?

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
        author = try container.decode(DiscordFeatureUserDTO.self, forKey: .author)
        member = try container.decodeIfPresent(DiscordFeatureGuildMemberDTO.self, forKey: .member)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        editedTimestamp = try container.decodeIfPresent(Date.self, forKey: .editedTimestamp)
        flags = try container.decodeIfPresent(Int.self, forKey: .flags)
        attachments = try container.decodeIfPresent([DiscordFeatureAttachmentDTO].self, forKey: .attachments)
        embeds = try container.decodeIfPresent([DiscordFeatureEmbedDTO].self, forKey: .embeds)
        mentions = try container.decodeIfPresent([DiscordFeatureUserDTO].self, forKey: .mentions)
        messageReference = try container.decodeIfPresent(MessageReferenceDTO.self, forKey: .messageReference)
        didLoadReferencedMessage = container.contains(.referencedMessage)
        referencedMessage = try container.decodeIfPresent(ReferencedMessageDTO.self, forKey: .referencedMessage)
        type = try container.decodeIfPresent(Int.self, forKey: .type)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned)
        reactions = try container.decodeIfPresent([DiscordFeatureReactionDTO].self, forKey: .reactions)
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
                memberNickname: member?.nick.normalized,
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

struct DiscordFeatureGuildMemberDTO: Decodable, Sendable {
    var nick: String?
    var roles: [RoleID]?
}

struct DiscordFeatureGuildMemberFullDTO: Decodable, Sendable {
    var user: DiscordFeatureUserDTO?
    var nick: String?
    var roles: [RoleID]?
    var joinedAt: Date?
    var deaf: Bool?
    var mute: Bool?
    var avatar: String?

    func toDomain(guildID: GuildID, fallbackUserID: UserID? = nil) -> (member: DiscordGuildMember, user: DiscordUser?)? {
        guard let userID = user?.id ?? fallbackUserID else { return nil }
        return (
            DiscordGuildMember(
                userID: userID,
                guildID: guildID,
                nickname: nick,
                roleIDs: roles ?? [],
                joinedAt: joinedAt,
                deaf: deaf ?? false,
                mute: mute ?? false,
                avatar: avatar
            ),
            user?.toDomain()
        )
    }
}

struct DiscordFeatureGuildBanDTO: Decodable, Sendable {
    var user: DiscordFeatureUserDTO
    var reason: String?

    func toDomain() -> (ban: DiscordGuildBan, user: DiscordUser) {
        (
            DiscordGuildBan(userID: user.id, reason: reason),
            user.toDomain()
        )
    }
}

struct DiscordFeatureAttachmentDTO: Decodable, Sendable {
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
            contentType: contentType.normalized,
            url: url,
            proxyURL: proxyUrl.normalized,
            width: width,
            height: height
        )
    }
}

struct DiscordFeatureEmbedDTO: Decodable, Sendable {
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
            url: url.normalized,
            title: title.normalized,
            description: description.normalized,
            thumbnailURL: thumbnail?.url.normalized,
            imageURL: image?.url.normalized,
            videoURL: video?.url.normalized
        )
    }
}

struct DiscordFeatureMessageSearchResponseDTO: Decodable, Sendable {
    var analyticsId: String?
    var totalResults: Int?
    var messages: [[DiscordFeatureMessageDTO]]
    var channels: [DiscordFeatureChannelDTO]?
}

