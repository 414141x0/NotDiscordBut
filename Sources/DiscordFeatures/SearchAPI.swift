import Foundation
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public final class SearchAPI: @unchecked Sendable {
    private let http: HTTPRuntime
    private let authorization: @Sendable () async -> DiscordAuthorization?
    private let store: StoreRuntime

    public init(
        http: HTTPRuntime,
        authorization: @escaping @Sendable () async -> DiscordAuthorization?,
        store: StoreRuntime
    ) {
        self.http = http
        self.authorization = authorization
        self.store = store
    }

    public func searchGuildMessages(
        in guildID: GuildID,
        query: String,
        channelIDs: [ChannelID] = [],
        limit: Int = 25
    ) async throws -> DiscordMessageSearchResults {
        var queryItems = [
            URLQueryItem(name: "content", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        queryItems.append(contentsOf: channelIDs.map { URLQueryItem(name: "channel_id", value: $0.rawValue) })

        var request = DiscordRequest<DiscordFeatureMessageSearchResponseDTO>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/messages/search",
            query: queryItems
        )
        request.authorization = await authorization()
        if request.authorization?.sessionKind == .user {
            request.headers = DiscordUserSessionRequestProfile.headers()
        }
        return try await applySearchResponse(try await http.execute(request).value)
    }

    public func searchPrivateChannelMessages(
        in channelID: ChannelID,
        query: String,
        limit: Int = 25
    ) async throws -> DiscordMessageSearchResults {
        var request = DiscordRequest<DiscordFeatureMessageSearchResponseDTO>(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages/search",
            query: [
                URLQueryItem(name: "content", value: query),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        request.authorization = await authorization()
        if request.authorization?.sessionKind == .user {
            request.headers = DiscordUserSessionRequestProfile.headers()
        }
        return try await applySearchResponse(try await http.execute(request).value)
    }

    private func applySearchResponse(_ response: DiscordFeatureMessageSearchResponseDTO) async throws -> DiscordMessageSearchResults {
        var usersByID = [String: DiscordUser]()
        var channelsByID = [String: DiscordChannel]()
        var messages = [DiscordMessage]()

        for channelPayload in response.channels ?? [] {
            if let mapped = channelPayload.toDomain(currentUserID: nil) {
                channelsByID[mapped.channel.id.rawValue] = mapped.channel
                for user in mapped.users {
                    usersByID[user.id.rawValue] = user
                }
            }
        }

        for group in response.messages {
            for payload in group {
                let mapped = payload.toDomain()
                messages.append(mapped.message)
                for user in mapped.users {
                    usersByID[user.id.rawValue] = user
                }
            }
        }

        try await store.apply(
            .merge(
                StateMergeSnapshot(
                    users: Array(usersByID.values),
                    channels: Array(channelsByID.values),
                    messages: messages
                )
            )
        )

        return DiscordMessageSearchResults(
            totalResults: response.totalResults ?? messages.count,
            messages: messages
        )
    }
}
