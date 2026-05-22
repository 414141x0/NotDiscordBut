import Foundation
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public final class MessagesAPI: @unchecked Sendable {
    private let http: HTTPRuntime
    private let authorization: @Sendable () async -> DiscordAuthorization?
    private let store: StoreRuntime
    private let query: QueryRuntime

    public init(
        http: HTTPRuntime,
        authorization: @escaping @Sendable () async -> DiscordAuthorization?,
        store: StoreRuntime,
        query: QueryRuntime
    ) {
        self.http = http
        self.authorization = authorization
        self.store = store
        self.query = query
    }

    public func list(
        in channelID: ChannelID,
        before: MessageID? = nil,
        after: MessageID? = nil,
        around: MessageID? = nil,
        limit: Int = 50
    ) async throws -> [DiscordMessage] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            queryItems.append(URLQueryItem(name: "before", value: before.rawValue))
        }
        if let after {
            queryItems.append(URLQueryItem(name: "after", value: after.rawValue))
        }
        if let around {
            queryItems.append(URLQueryItem(name: "around", value: around.rawValue))
        }

        var request = DiscordRequest<[DiscordFeatureMessageDTO]>(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages",
            query: queryItems
        )
        request.authorization = await authorization()

        let payloads = try await http.execute(request).value
        var usersByID = [String: DiscordUser]()
        var messages = [DiscordMessage]()
        for payload in payloads {
            let mapped = payload.toDomain()
            messages.append(mapped.message)
            for user in mapped.users {
                usersByID[user.id.rawValue] = user
            }
        }

        try await store.apply(.merge(StateMergeSnapshot(users: Array(usersByID.values), messages: messages)))
        return messages
    }

    public func send(_ input: MessageSendInput) async throws -> DiscordMessage {
        struct Request: Codable, Sendable {
            struct MessageReference: Codable, Sendable {
                var messageID: MessageID
                var channelID: ChannelID
                var guildID: GuildID?
            }

            var content: String
            var nonce: MessageNonce?
            var messageReference: MessageReference?
            var tts: Bool
            var flags: Int
            var mobileNetworkType: String
        }

        let previewID = MessageID(rawValue: input.nonce?.rawValue ?? UUID().uuidString)
        try await store.apply(
            .optimisticMessageSend(
                PendingMessageOperation(
                    messageID: previewID,
                    channelID: input.channelID,
                    content: input.content
                )
            )
        )

        var request = DiscordRequest<DiscordFeatureMessageDTO>(
            method: .post,
            path: "/channels/\(input.channelID.rawValue)/messages",
            body: AnyEncodable(
                Request(
                    content: input.content,
                    nonce: input.nonce,
                    messageReference: input.messageReference.map { reference in
                        Request.MessageReference(
                            messageID: reference.messageID,
                            channelID: reference.channelID,
                            guildID: reference.guildID
                        )
                    },
                    tts: false,
                    flags: 0,
                    mobileNetworkType: "unknown"
                )
            )
        )
        request.authorization = await authorization()
        if request.authorization?.sessionKind == .user {
            request.headers = DiscordUserSessionRequestProfile.headers()
        }

        let payload = try await http.execute(request).value
        let mapped = payload.toDomain()
        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, messages: [mapped.message])))
        return mapped.message
    }

    public func acknowledge(channelID: ChannelID, messageID: MessageID) async throws {
        struct Request: Codable, Sendable {
            var token: String? = nil
            var lastViewed: Int? = nil
        }

        var request = DiscordRequest<VoidResponse>(
            method: .post,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/ack",
            body: AnyEncodable(Request())
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.readStateUpdate(.init(channelID: channelID, lastMessageID: messageID)))
    }

    public func get(channelID: ChannelID, messageID: MessageID) async throws -> DiscordMessage {
        var request = DiscordRequest<DiscordFeatureMessageDTO>(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let mapped = payload.toDomain()
        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, messages: [mapped.message])))
        return mapped.message
    }

    public func edit(_ input: MessageEditInput) async throws -> DiscordMessage {
        struct Request: Codable, Sendable {
            var content: String
        }

        var request = DiscordRequest<DiscordFeatureMessageDTO>(
            method: .patch,
            path: "/channels/\(input.channelID.rawValue)/messages/\(input.messageID.rawValue)",
            body: AnyEncodable(Request(content: input.content))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let mapped = payload.toDomain()
        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, messages: [mapped.message])))
        return mapped.message
    }

    public func delete(channelID: ChannelID, messageID: MessageID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.messageDelete(channelID: channelID, messageID: messageID))
    }

    public func addReaction(_ input: ReactionInput) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/channels/\(input.channelID.rawValue)/messages/\(input.messageID.rawValue)/reactions/\(input.emoji.urlEncoded)/@me"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func removeReaction(_ input: ReactionInput) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(input.channelID.rawValue)/messages/\(input.messageID.rawValue)/reactions/\(input.emoji.urlEncoded)/0/@me"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func getReactions(
        channelID: ChannelID,
        messageID: MessageID,
        emoji: DiscordReactionEmoji,
        limit: Int = 25
    ) async throws -> [DiscordUser] {
        var request = DiscordRequest<[DiscordFeatureUserDTO]>(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/reactions/\(emoji.urlEncoded)",
            query: [URLQueryItem(name: "limit", value: String(limit))]
        )
        request.authorization = await authorization()

        let payloads = try await http.execute(request).value
        let users = payloads.map { $0.toDomain() }
        try await store.apply(.merge(StateMergeSnapshot(users: users)))
        return users
    }

    public func removeAllReactions(channelID: ChannelID, messageID: MessageID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/reactions"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func sendTypingIndicator(channelID: ChannelID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .post,
            path: "/channels/\(channelID.rawValue)/typing"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func getPinnedMessages(channelID: ChannelID) async throws -> [DiscordMessage] {
        var request = DiscordRequest<[DiscordFeatureMessageDTO]>(
            method: .get,
            path: "/channels/\(channelID.rawValue)/pins"
        )
        request.authorization = await authorization()

        let payloads = try await http.execute(request).value
        var usersByID = [String: DiscordUser]()
        var messages = [DiscordMessage]()
        for payload in payloads {
            let mapped = payload.toDomain()
            messages.append(mapped.message)
            for user in mapped.users {
                usersByID[user.id.rawValue] = user
            }
        }

        try await store.apply(.merge(StateMergeSnapshot(users: Array(usersByID.values), messages: messages)))
        return messages
    }

    public func pinMessage(channelID: ChannelID, messageID: MessageID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/channels/\(channelID.rawValue)/pins/\(messageID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func unpinMessage(channelID: ChannelID, messageID: MessageID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/pins/\(messageID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func timelineProjection(for channelID: ChannelID?) async -> TimelineProjection {
        let snapshot = await store.snapshot()
        return query.timelineProjection(for: channelID, from: snapshot)
    }
}
