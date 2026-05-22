import Foundation
import DiscordPrimitives

public enum StateReducerAction: Sendable, Hashable {
    case ready(ReadySnapshot)
    case readySupplemental(ReadySupplementalSnapshot)
    case merge(StateMergeSnapshot)
    case optimisticMessageSend(PendingMessageOperation)
    case messageUpsert(DiscordMessage)
    case readStateUpdate(DiscordReadState)
    case messageDelete(channelID: ChannelID, messageID: MessageID)
    case channelDelete(ChannelID)
    case guildMemberRemove(guildID: GuildID, userID: UserID)
    case userNoteUpdate(DiscordUserNote)
    case relationshipRemove(UserID)
    case relationshipAdd(DiscordRelationship)
    case authSessionDidChange(AuthSessionIDHash)
}

public enum StateReducer {
    public static func apply(_ action: StateReducerAction, to state: inout NormalizedState) {
        switch action {
        case let .ready(snapshot):
            if let user = snapshot.user {
                merge(user, into: &state)
            }

            for guild in snapshot.guilds {
                merge(guild, into: &state)
            }

            for channel in snapshot.privateChannels {
                merge(channel, into: &state)
            }

            for relationship in snapshot.relationships {
                state.relationships[relationship.userID.rawValue] = relationship
            }

            for readState in snapshot.readStates {
                state.readStates[readState.channelID.rawValue] = readState
            }

            state.session = snapshot.session

        case let .readySupplemental(snapshot):
            for guildID in snapshot.guildIDs where state.guilds[guildID.rawValue] == nil {
                state.guilds[guildID.rawValue] = DiscordGuild(id: guildID, name: "Unknown Guild", unavailable: false)
            }

        case let .merge(snapshot):
            for user in snapshot.users {
                merge(user, into: &state)
            }

            for profile in snapshot.userProfiles {
                merge(profile, into: &state)
            }

            for guild in snapshot.guilds {
                merge(guild, into: &state)
            }

            for guildRole in snapshot.guildRoles {
                merge(guildRole, into: &state)
            }

            for guildEmoji in snapshot.guildEmojis {
                merge(guildEmoji, into: &state)
            }

            for channel in snapshot.channels {
                merge(channel, into: &state)
            }

            for message in snapshot.messages {
                state.messages[message.id.rawValue] = message
            }

            for relationship in snapshot.relationships {
                state.relationships[relationship.userID.rawValue] = relationship
            }

            for readState in snapshot.readStates {
                state.readStates[readState.channelID.rawValue] = readState
            }

            for member in snapshot.guildMembers {
                state.guildMembers["\(member.guildID.rawValue):\(member.userID.rawValue)"] = member
            }

        case let .optimisticMessageSend(operation):
            let preview = DiscordMessage(
                id: operation.messageID,
                channelID: operation.channelID,
                authorID: "local-user",
                content: operation.content,
                timestamp: operation.createdAt,
                flags: [.loading]
            )
            state.messages[operation.messageID.rawValue] = preview
            state.pendingMessageOperations[operation.messageID.rawValue] = operation

        case let .messageUpsert(message):
            state.messages[message.id.rawValue] = message
            state.pendingMessageOperations.removeValue(forKey: message.id.rawValue)

        case let .readStateUpdate(readState):
            state.readStates[readState.channelID.rawValue] = readState

        case let .messageDelete(_, messageID):
            state.messages.removeValue(forKey: messageID.rawValue)

        case let .channelDelete(channelID):
            state.channels.removeValue(forKey: channelID.rawValue)

        case let .guildMemberRemove(guildID, userID):
            state.guildMembers.removeValue(forKey: "\(guildID.rawValue):\(userID.rawValue)")

        case let .userNoteUpdate(note):
            state.userNotes[note.userID.rawValue] = note

        case let .relationshipRemove(userID):
            state.relationships.removeValue(forKey: userID.rawValue)

        case let .relationshipAdd(relationship):
            state.relationships[relationship.userID.rawValue] = relationship

        case let .authSessionDidChange(hash):
            state.session.authSessionIDHash = hash
        }
    }
}

private func merge(_ user: DiscordUser, into state: inout NormalizedState) {
    if let existing = state.users[user.id.rawValue] {
        state.users[user.id.rawValue] = existing.merged(with: user)
    } else {
        state.users[user.id.rawValue] = user
    }
}

private func merge(_ profile: DiscordUserProfile, into state: inout NormalizedState) {
    if let existing = state.userProfiles[profile.userID.rawValue] {
        state.userProfiles[profile.userID.rawValue] = existing.merged(with: profile)
    } else {
        state.userProfiles[profile.userID.rawValue] = profile
    }
}

private func merge(_ guild: DiscordGuild, into state: inout NormalizedState) {
    if let existing = state.guilds[guild.id.rawValue] {
        state.guilds[guild.id.rawValue] = existing.merged(with: guild)
    } else {
        state.guilds[guild.id.rawValue] = guild
    }
}

private func merge(_ guildRole: DiscordGuildRole, into state: inout NormalizedState) {
    state.guildRoles[guildRole.id.rawValue] = guildRole
}

private func merge(_ guildEmoji: DiscordGuildEmoji, into state: inout NormalizedState) {
    state.guildEmojis[guildEmoji.id] = guildEmoji
}

private func merge(_ channel: DiscordChannel, into state: inout NormalizedState) {
    if let existing = state.channels[channel.id.rawValue] {
        state.channels[channel.id.rawValue] = existing.merged(with: channel)
    } else {
        state.channels[channel.id.rawValue] = channel
    }
}
