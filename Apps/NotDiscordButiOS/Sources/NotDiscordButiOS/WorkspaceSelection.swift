import DiscordKit

enum WorkspaceSelection: Hashable, Codable, Sendable {
    case friend(UserID)
    case guild(GuildID)
}

struct WorkspacePerson: Hashable, Sendable {
    var user: DiscordUser
    var relationship: DiscordRelationship?
    var existingChannelID: ChannelID?

    init(
        user: DiscordUser,
        relationship: DiscordRelationship? = nil,
        existingChannelID: ChannelID? = nil
    ) {
        self.user = user
        self.relationship = relationship
        self.existingChannelID = existingChannelID
    }

    var displayName: String {
        user.displayName
    }

    var detailText: String {
        switch relationship?.kind {
        case .friend:
            return relationship?.nickname ?? "Friend"
        case .incomingRequest:
            return "Incoming request"
        case .outgoingRequest:
            return "Outgoing request"
        case .blocked:
            return "Blocked"
        case .implicit:
            return "Affinity"
        case nil:
            return existingChannelID == nil ? "Conversation" : "Direct message"
        }
    }
}

extension WorkspaceSelection {
    var persistenceKey: String {
        switch self {
        case let .friend(userID):
            "friend:\(userID.rawValue)"
        case let .guild(guildID):
            "guild:\(guildID.rawValue)"
        }
    }

    var guildID: GuildID? {
        switch self {
        case let .guild(guildID):
            guildID
        case .friend:
            nil
        }
    }

    var userID: UserID? {
        switch self {
        case let .friend(userID):
            userID
        case .guild:
            nil
        }
    }
}
