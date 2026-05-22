import Foundation
import DiscordPrimitives

public enum GatewayOpcode: Int, Codable, Sendable, Hashable {
    case dispatch = 0
    case heartbeat = 1
    case identify = 2
    case resume = 6
    case reconnect = 7
    case requestGuildMembers = 8
    case invalidSession = 9
    case hello = 10
    case heartbeatAck = 11
}

public struct GatewayClientState: Codable, Hashable, Sendable {
    public var apiCodeVersion: Int
    public var guildVersions: [String: Int]

    public init(apiCodeVersion: Int = 0, guildVersions: [String: Int] = [:]) {
        self.apiCodeVersion = apiCodeVersion
        self.guildVersions = guildVersions
    }
}

public struct GatewayIdentifyProperties: Codable, Hashable, Sendable {
    public var os: String
    public var browser: String
    public var device: String

    public init(os: String, browser: String, device: String) {
        self.os = os
        self.browser = browser
        self.device = device
    }
}

public struct GatewayIdentifyPayload: Codable, Hashable, Sendable {
    public var token: String
    public var properties: GatewayIdentifyProperties
    public var capabilities: CapabilityMask
    public var intents: IntentMask
    public var clientState: GatewayClientState

    public init(
        token: String,
        properties: GatewayIdentifyProperties,
        capabilities: CapabilityMask,
        intents: IntentMask,
        clientState: GatewayClientState
    ) {
        self.token = token
        self.properties = properties
        self.capabilities = capabilities
        self.intents = intents
        self.clientState = clientState
    }
}

extension GatewayIdentifyPayload {
    enum CodingKeys: String, CodingKey {
        case token
        case properties
        case capabilities
        case intents
        case clientState = "client_state"
    }
}

public struct GatewayResumePayload: Codable, Hashable, Sendable {
    public var token: String
    public var sessionID: String
    public var sequence: Int

    public init(token: String, sessionID: String, sequence: Int) {
        self.token = token
        self.sessionID = sessionID
        self.sequence = sequence
    }
}

extension GatewayResumePayload {
    enum CodingKeys: String, CodingKey {
        case token
        case sessionID = "session_id"
        case sequence = "seq"
    }
}

public struct GatewayReady: Codable, Hashable, Sendable {
    public var version: Int
    public var user: DiscordUser
    public var userSettings: DiscordUserSettings?
    public var notificationSettings: DiscordNotificationSettings?
    public var guilds: [DiscordGuild]
    public var relationships: [DiscordRelationship]
    public var privateChannels: [DiscordChannel]
    public var readStates: [DiscordReadState]
    public var sessionID: String
    public var resumeGatewayURL: URL
    public var authSessionIDHash: AuthSessionIDHash

    public init(
        version: Int,
        user: DiscordUser,
        userSettings: DiscordUserSettings? = nil,
        notificationSettings: DiscordNotificationSettings? = nil,
        guilds: [DiscordGuild] = [],
        relationships: [DiscordRelationship] = [],
        privateChannels: [DiscordChannel] = [],
        readStates: [DiscordReadState] = [],
        sessionID: String,
        resumeGatewayURL: URL,
        authSessionIDHash: AuthSessionIDHash
    ) {
        self.version = version
        self.user = user
        self.userSettings = userSettings
        self.notificationSettings = notificationSettings
        self.guilds = guilds
        self.relationships = relationships
        self.privateChannels = privateChannels
        self.readStates = readStates
        self.sessionID = sessionID
        self.resumeGatewayURL = resumeGatewayURL
        self.authSessionIDHash = authSessionIDHash
    }
}

extension GatewayReady {
    enum CodingKeys: String, CodingKey {
        case version = "v"
        case user
        case userSettings = "userSettings"
        case notificationSettings = "notificationSettings"
        case guilds
        case relationships
        case privateChannels = "privateChannels"
        case readStates = "readState"
        case sessionID = "sessionId"
        case resumeGatewayURL = "resumeGatewayUrl"
        case authSessionIDHash = "authSessionIdHash"
    }

    public static func stub(authSessionIDHash: String) -> GatewayReady {
        GatewayReady(
            version: 9,
            user: DiscordUser(id: "1", username: "preview"),
            guilds: [],
            relationships: [],
            privateChannels: [],
            readStates: [],
            sessionID: "session-1",
            resumeGatewayURL: URL(string: "wss://gateway.discord.gg")!,
            authSessionIDHash: AuthSessionIDHash(rawValue: authSessionIDHash)
        )
    }
}

public struct GatewaySupplementalGuild: Codable, Hashable, Sendable {
    public var id: GuildID

    public init(id: GuildID) {
        self.id = id
    }
}

public struct GatewayReadySupplemental: Codable, Hashable, Sendable {
    public var guilds: [GatewaySupplementalGuild]

    public init(guilds: [GatewaySupplementalGuild]) {
        self.guilds = guilds
    }
}

extension GatewayReadySupplemental {
    public static func stub(guildID: String) -> GatewayReadySupplemental {
        GatewayReadySupplemental(guilds: [.init(id: GuildID(rawValue: guildID))])
    }
}

public struct GatewayAuthSessionChange: Codable, Hashable, Sendable {
    public var authSessionIDHash: AuthSessionIDHash

    public init(authSessionIDHash: AuthSessionIDHash) {
        self.authSessionIDHash = authSessionIDHash
    }
}

extension GatewayAuthSessionChange {
    enum CodingKeys: String, CodingKey {
        case authSessionIDHash = "authSessionIdHash"
    }
}

public struct GatewayTypingStart: Codable, Hashable, Sendable {
    public var channelID: ChannelID
    public var userID: UserID
    public var guildID: GuildID?
    public var timestamp: Date

    public init(channelID: ChannelID, userID: UserID, guildID: GuildID? = nil, timestamp: Date) {
        self.channelID = channelID
        self.userID = userID
        self.guildID = guildID
        self.timestamp = timestamp
    }
}

public struct GatewayMessageDelete: Codable, Hashable, Sendable {
    public var channelID: ChannelID
    public var messageID: MessageID
    public var guildID: GuildID?

    public init(channelID: ChannelID, messageID: MessageID, guildID: GuildID? = nil) {
        self.channelID = channelID
        self.messageID = messageID
        self.guildID = guildID
    }
}

public struct GatewayReactionUpdate: Codable, Hashable, Sendable {
    public var channelID: ChannelID
    public var messageID: MessageID
    public var userID: UserID
    public var guildID: GuildID?
    public var emoji: DiscordReactionEmoji

    public init(channelID: ChannelID, messageID: MessageID, userID: UserID, guildID: GuildID? = nil, emoji: DiscordReactionEmoji) {
        self.channelID = channelID
        self.messageID = messageID
        self.userID = userID
        self.guildID = guildID
        self.emoji = emoji
    }
}

public struct GatewayGuildMemberRemove: Codable, Hashable, Sendable {
    public var guildID: GuildID
    public var userID: UserID

    public init(guildID: GuildID, userID: UserID) {
        self.guildID = guildID
        self.userID = userID
    }
}

public enum GatewayEvent: Sendable, Hashable {
    case ready(GatewayReady)
    case readySupplemental(GatewayReadySupplemental)
    case resumed
    case authSessionChange(GatewayAuthSessionChange)
    case messageCreate(DiscordMessage, users: [DiscordUser])
    case messageUpdate(DiscordMessage, users: [DiscordUser])
    case messageDelete(GatewayMessageDelete)
    case typingStart(GatewayTypingStart)
    case channelCreate(DiscordChannel)
    case channelUpdate(DiscordChannel)
    case channelDelete(DiscordChannel)
    case presenceUpdate(DiscordPresence)
    case relationshipAdd(DiscordRelationship, user: DiscordUser)
    case relationshipRemove(userID: UserID)
    case messageReactionAdd(GatewayReactionUpdate)
    case messageReactionRemove(GatewayReactionUpdate)
    case guildMemberAdd(DiscordGuildMember, user: DiscordUser)
    case guildMemberUpdate(DiscordGuildMember)
    case guildMemberRemove(GatewayGuildMemberRemove)
    case unknown(name: String, payload: Data)
}
