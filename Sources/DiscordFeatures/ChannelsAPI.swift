import Foundation
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public final class ChannelsAPI: @unchecked Sendable {
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

    public func privateChannels() async -> [DiscordChannel] {
        let snapshot = await store.snapshot()
        return query.sidebarProjection(from: snapshot).privateChannels
    }

    public func projection(for guildID: GuildID?) async -> ChannelListProjection {
        let snapshot = await store.snapshot()
        return query.channelListProjection(for: guildID, from: snapshot)
    }

    public func get(channelID: ChannelID) async throws -> DiscordChannel {
        var request = DiscordRequest<DiscordFeatureChannelDTO>(
            method: .get,
            path: "/channels/\(channelID.rawValue)"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let mapped = payload.toDomain(currentUserID: await currentUserID()) else {
            throw DiscordHTTPError.decodingFailed("Could not map channel payload into a domain channel.")
        }

        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, channels: [mapped.channel])))
        return mapped.channel
    }

    public func edit(_ input: ChannelEditInput) async throws -> DiscordChannel {
        struct Request: Codable, Sendable {
            var name: String?
            var topic: String?
            var nsfw: Bool?
            var rateLimitPerUser: Int?
        }

        var request = DiscordRequest<DiscordFeatureChannelDTO>(
            method: .patch,
            path: "/channels/\(input.channelID.rawValue)",
            body: AnyEncodable(Request(
                name: input.name,
                topic: input.topic,
                nsfw: input.nsfw,
                rateLimitPerUser: input.rateLimitPerUser
            ))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let mapped = payload.toDomain(currentUserID: await currentUserID()) else {
            throw DiscordHTTPError.decodingFailed("Could not map edited channel payload into a domain channel.")
        }

        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, channels: [mapped.channel])))
        return mapped.channel
    }

    public func delete(channelID: ChannelID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(channelID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.channelDelete(channelID))
    }

    public func addRecipient(channelID: ChannelID, userID: UserID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/channels/\(channelID.rawValue)/recipients/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func removeRecipient(channelID: ChannelID, userID: UserID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/recipients/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func createThread(
        channelID: ChannelID,
        name: String,
        autoArchiveDuration: Int = 1440
    ) async throws -> DiscordChannel {
        struct Request: Codable, Sendable {
            var name: String
            var autoArchiveDuration: Int
        }

        var request = DiscordRequest<DiscordFeatureChannelDTO>(
            method: .post,
            path: "/channels/\(channelID.rawValue)/threads",
            body: AnyEncodable(Request(name: name, autoArchiveDuration: autoArchiveDuration))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let mapped = payload.toDomain(currentUserID: await currentUserID()) else {
            throw DiscordHTTPError.decodingFailed("Could not map thread channel payload.")
        }

        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, channels: [mapped.channel])))
        return mapped.channel
    }

    public func createThreadFromMessage(
        channelID: ChannelID,
        messageID: MessageID,
        name: String,
        autoArchiveDuration: Int = 1440
    ) async throws -> DiscordChannel {
        struct Request: Codable, Sendable {
            var name: String
            var autoArchiveDuration: Int
        }

        var request = DiscordRequest<DiscordFeatureChannelDTO>(
            method: .post,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/threads",
            body: AnyEncodable(Request(name: name, autoArchiveDuration: autoArchiveDuration))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let mapped = payload.toDomain(currentUserID: await currentUserID()) else {
            throw DiscordHTTPError.decodingFailed("Could not map thread channel payload.")
        }

        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, channels: [mapped.channel])))
        return mapped.channel
    }

    public func joinThread(channelID: ChannelID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/channels/\(channelID.rawValue)/thread-members/@me"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func leaveThread(channelID: ChannelID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/thread-members/@me"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func listArchivedThreads(channelID: ChannelID) async throws -> [DiscordChannel] {
        struct Response: Decodable, Sendable {
            var threads: [DiscordFeatureChannelDTO]
        }

        var request = DiscordRequest<Response>(
            method: .get,
            path: "/channels/\(channelID.rawValue)/threads/archived/public"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let currentUser = await currentUserID()
        var channels = [DiscordChannel]()
        var users = [DiscordUser]()
        for dto in payload.threads {
            guard let mapped = dto.toDomain(currentUserID: currentUser) else { continue }
            channels.append(mapped.channel)
            users.append(contentsOf: mapped.users)
        }

        try await store.apply(.merge(StateMergeSnapshot(users: users, channels: channels)))
        return channels
    }

    public func listActiveThreads(guildID: GuildID) async throws -> [DiscordChannel] {
        struct Response: Decodable, Sendable {
            var threads: [DiscordFeatureChannelDTO]
        }

        var request = DiscordRequest<Response>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/threads/active"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let currentUser = await currentUserID()
        var channels = [DiscordChannel]()
        var users = [DiscordUser]()
        for dto in payload.threads {
            guard let mapped = dto.toDomain(currentUserID: currentUser) else { continue }
            channels.append(mapped.channel)
            users.append(contentsOf: mapped.users)
        }

        try await store.apply(.merge(StateMergeSnapshot(users: users, channels: channels)))
        return channels
    }

    public func createDM(with userID: UserID) async throws -> DiscordChannel {
        struct Request: Codable, Sendable {
            var recipientID: UserID
        }

        struct ResponseChannel: Decodable, Sendable {
            var id: ChannelID
            var type: Int
            var name: String?
            var lastMessageId: MessageID?
            var recipients: [DiscordFeatureUserDTO]?

            func toFeatureDTO() -> DiscordFeatureChannelDTO {
                DiscordFeatureChannelDTO(
                    id: id,
                    type: type,
                    guildId: nil,
                    name: name,
                    lastMessageId: lastMessageId,
                    recipients: recipients,
                    icon: nil,
                    topic: nil,
                    position: nil
                )
            }
        }

        var request = DiscordRequest<ResponseChannel>(
            method: .post,
            path: "/users/@me/channels",
            body: AnyEncodable(Request(recipientID: userID))
        )
        request.authorization = await authorization()

        let response = try await http.execute(request).value
        guard let mapped = response.toFeatureDTO().toDomain(currentUserID: await currentUserID()) else {
            throw DiscordHTTPError.decodingFailed("Could not map DM channel payload into a domain channel.")
        }

        try await store.apply(.merge(StateMergeSnapshot(users: mapped.users, channels: [mapped.channel])))
        return mapped.channel
    }

    private func currentUserID() async -> UserID? {
        let snapshot = await store.snapshot()
        return snapshot.users.values.first?.id
    }
}
