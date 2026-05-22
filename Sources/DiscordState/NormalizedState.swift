import Foundation
import DiscordPersistence
import DiscordPrimitives

public struct StateSessionMetadata: Codable, Hashable, Sendable {
    public var authSessionIDHash: AuthSessionIDHash?
    public var resumeGatewayURL: URL?
    public var sessionID: String?

    public init(authSessionIDHash: AuthSessionIDHash? = nil, resumeGatewayURL: URL? = nil, sessionID: String? = nil) {
        self.authSessionIDHash = authSessionIDHash
        self.resumeGatewayURL = resumeGatewayURL
        self.sessionID = sessionID
    }
}

public struct PendingMessageOperation: Codable, Hashable, Sendable {
    public var messageID: MessageID
    public var channelID: ChannelID
    public var content: String
    public var createdAt: Date

    public init(messageID: MessageID, channelID: ChannelID, content: String, createdAt: Date = .now) {
        self.messageID = messageID
        self.channelID = channelID
        self.content = content
        self.createdAt = createdAt
    }

    public static func makePreview(channelID: String, messageID: String) -> PendingMessageOperation {
        PendingMessageOperation(
            messageID: MessageID(rawValue: messageID),
            channelID: ChannelID(rawValue: channelID),
            content: "preview"
        )
    }
}

public struct ReadySnapshot: Codable, Hashable, Sendable {
    public var user: DiscordUser?
    public var guilds: [DiscordGuild]
    public var privateChannels: [DiscordChannel]
    public var relationships: [DiscordRelationship]
    public var readStates: [DiscordReadState]
    public var session: StateSessionMetadata

    public init(
        user: DiscordUser? = nil,
        guilds: [DiscordGuild] = [],
        privateChannels: [DiscordChannel] = [],
        relationships: [DiscordRelationship] = [],
        readStates: [DiscordReadState] = [],
        session: StateSessionMetadata = .init()
    ) {
        self.user = user
        self.guilds = guilds
        self.privateChannels = privateChannels
        self.relationships = relationships
        self.readStates = readStates
        self.session = session
    }
}

public struct ReadySupplementalSnapshot: Codable, Hashable, Sendable {
    public var guildIDs: [GuildID]

    public init(guildIDs: [GuildID]) {
        self.guildIDs = guildIDs
    }
}

public struct StateMergeSnapshot: Codable, Hashable, Sendable {
    public var users: [DiscordUser]
    public var userProfiles: [DiscordUserProfile]
    public var guilds: [DiscordGuild]
    public var guildRoles: [DiscordGuildRole]
    public var guildEmojis: [DiscordGuildEmoji]
    public var channels: [DiscordChannel]
    public var messages: [DiscordMessage]
    public var relationships: [DiscordRelationship]
    public var readStates: [DiscordReadState]
    public var guildMembers: [DiscordGuildMember]

    public init(
        users: [DiscordUser] = [],
        userProfiles: [DiscordUserProfile] = [],
        guilds: [DiscordGuild] = [],
        guildRoles: [DiscordGuildRole] = [],
        guildEmojis: [DiscordGuildEmoji] = [],
        channels: [DiscordChannel] = [],
        messages: [DiscordMessage] = [],
        relationships: [DiscordRelationship] = [],
        readStates: [DiscordReadState] = [],
        guildMembers: [DiscordGuildMember] = []
    ) {
        self.users = users
        self.userProfiles = userProfiles
        self.guilds = guilds
        self.guildRoles = guildRoles
        self.guildEmojis = guildEmojis
        self.channels = channels
        self.messages = messages
        self.relationships = relationships
        self.readStates = readStates
        self.guildMembers = guildMembers
    }
}

public struct NormalizedState: Codable, Hashable, Sendable {
    public var users: [String: DiscordUser]
    public var userProfiles: [String: DiscordUserProfile]
    public var guilds: [String: DiscordGuild]
    public var guildRoles: [String: DiscordGuildRole]
    public var guildEmojis: [String: DiscordGuildEmoji]
    public var channels: [String: DiscordChannel]
    public var messages: [String: DiscordMessage]
    public var relationships: [String: DiscordRelationship]
    public var readStates: [String: DiscordReadState]
    public var pendingMessageOperations: [String: PendingMessageOperation]
    public var guildMembers: [String: DiscordGuildMember]
    public var userNotes: [String: DiscordUserNote]
    public var session: StateSessionMetadata

    public init(
        users: [String: DiscordUser] = [:],
        userProfiles: [String: DiscordUserProfile] = [:],
        guilds: [String: DiscordGuild] = [:],
        guildRoles: [String: DiscordGuildRole] = [:],
        guildEmojis: [String: DiscordGuildEmoji] = [:],
        channels: [String: DiscordChannel] = [:],
        messages: [String: DiscordMessage] = [:],
        relationships: [String: DiscordRelationship] = [:],
        readStates: [String: DiscordReadState] = [:],
        pendingMessageOperations: [String: PendingMessageOperation] = [:],
        guildMembers: [String: DiscordGuildMember] = [:],
        userNotes: [String: DiscordUserNote] = [:],
        session: StateSessionMetadata = .init()
    ) {
        self.users = users
        self.userProfiles = userProfiles
        self.guilds = guilds
        self.guildRoles = guildRoles
        self.guildEmojis = guildEmojis
        self.channels = channels
        self.messages = messages
        self.relationships = relationships
        self.readStates = readStates
        self.pendingMessageOperations = pendingMessageOperations
        self.guildMembers = guildMembers
        self.userNotes = userNotes
        self.session = session
    }

    enum CodingKeys: String, CodingKey {
        case users
        case userProfiles
        case guilds
        case guildRoles
        case guildEmojis
        case channels
        case messages
        case relationships
        case readStates
        case pendingMessageOperations
        case guildMembers
        case userNotes
        case session
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decodeIfPresent([String: DiscordUser].self, forKey: .users) ?? [:]
        userProfiles = try container.decodeIfPresent([String: DiscordUserProfile].self, forKey: .userProfiles) ?? [:]
        guilds = try container.decodeIfPresent([String: DiscordGuild].self, forKey: .guilds) ?? [:]
        guildRoles = try container.decodeIfPresent([String: DiscordGuildRole].self, forKey: .guildRoles) ?? [:]
        guildEmojis = try container.decodeIfPresent([String: DiscordGuildEmoji].self, forKey: .guildEmojis) ?? [:]
        channels = try container.decodeIfPresent([String: DiscordChannel].self, forKey: .channels) ?? [:]
        messages = try container.decodeIfPresent([String: DiscordMessage].self, forKey: .messages) ?? [:]
        relationships = try container.decodeIfPresent([String: DiscordRelationship].self, forKey: .relationships) ?? [:]
        readStates = try container.decodeIfPresent([String: DiscordReadState].self, forKey: .readStates) ?? [:]
        pendingMessageOperations = try container.decodeIfPresent([String: PendingMessageOperation].self, forKey: .pendingMessageOperations) ?? [:]
        guildMembers = try container.decodeIfPresent([String: DiscordGuildMember].self, forKey: .guildMembers) ?? [:]
        userNotes = try container.decodeIfPresent([String: DiscordUserNote].self, forKey: .userNotes) ?? [:]
        session = try container.decodeIfPresent(StateSessionMetadata.self, forKey: .session) ?? .init()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(users, forKey: .users)
        try container.encode(userProfiles, forKey: .userProfiles)
        try container.encode(guilds, forKey: .guilds)
        try container.encode(guildRoles, forKey: .guildRoles)
        try container.encode(guildEmojis, forKey: .guildEmojis)
        try container.encode(channels, forKey: .channels)
        try container.encode(messages, forKey: .messages)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(readStates, forKey: .readStates)
        try container.encode(pendingMessageOperations, forKey: .pendingMessageOperations)
        try container.encode(guildMembers, forKey: .guildMembers)
        try container.encode(userNotes, forKey: .userNotes)
        try container.encode(session, forKey: .session)
    }

    public static let empty = NormalizedState()
}
