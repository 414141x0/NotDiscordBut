import Foundation

public struct CapabilityMask: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    @inlinable
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let lazyUserNotes = Self(rawValue: 1 << 0)
    public static let noAffineUserIDs = Self(rawValue: 1 << 1)
    public static let versionedReadStates = Self(rawValue: 1 << 2)
    public static let versionedUserGuildSettings = Self(rawValue: 1 << 3)
    public static let dedupeUserObjects = Self(rawValue: 1 << 4)
    public static let prioritizedReadyPayload = Self(rawValue: 1 << 5)
    public static let nonChannelReadStates = Self(rawValue: 1 << 7)
    public static let authTokenRefresh = Self(rawValue: 1 << 8)
    public static let userSettingsProto = Self(rawValue: 1 << 9)

    public static let clientCoreDefault: Self = [
        .versionedReadStates,
        .versionedUserGuildSettings,
        .prioritizedReadyPayload,
        .nonChannelReadStates,
        .userSettingsProto
    ]
}

public struct IntentMask: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    @inlinable
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let guilds = Self(rawValue: 1 << 0)
    public static let guildMembers = Self(rawValue: 1 << 1)
    public static let guildModeration = Self(rawValue: 1 << 2)
    public static let guildExpressions = Self(rawValue: 1 << 3)
    public static let guildIntegrations = Self(rawValue: 1 << 4)
    public static let guildWebhooks = Self(rawValue: 1 << 5)
    public static let guildInvites = Self(rawValue: 1 << 6)
    public static let guildVoiceStates = Self(rawValue: 1 << 7)
    public static let guildPresences = Self(rawValue: 1 << 8)
    public static let guildMessages = Self(rawValue: 1 << 9)
    public static let guildMessageReactions = Self(rawValue: 1 << 10)
    public static let directMessages = Self(rawValue: 1 << 12)
    public static let directMessageReactions = Self(rawValue: 1 << 13)
    public static let messageContent = Self(rawValue: 1 << 15)

    public static let clientCoreDefault: Self = [
        .guilds,
        .guildMembers,
        .guildPresences,
        .guildMessages,
        .guildMessageReactions,
        .directMessages,
        .directMessageReactions,
        .messageContent
    ]
}

public struct MessageFlags: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    @inlinable
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let crossposted = Self(rawValue: 1 << 0)
    public static let suppressEmbeds = Self(rawValue: 1 << 2)
    public static let hasThread = Self(rawValue: 1 << 5)
    public static let ephemeral = Self(rawValue: 1 << 6)
    public static let loading = Self(rawValue: 1 << 7)
    public static let suppressNotifications = Self(rawValue: 1 << 12)
    public static let voiceMessage = Self(rawValue: 1 << 13)
}

