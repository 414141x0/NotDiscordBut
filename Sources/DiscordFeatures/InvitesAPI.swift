import Foundation
import DiscordHTTP
import DiscordPrimitives

public final class InvitesAPI: @unchecked Sendable {
    private let http: HTTPRuntime
    private let authorization: @Sendable () async -> DiscordAuthorization?

    public init(
        http: HTTPRuntime,
        authorization: @escaping @Sendable () async -> DiscordAuthorization?
    ) {
        self.http = http
        self.authorization = authorization
    }

    public func preview(code: String) async throws -> DiscordInvite {
        var request = DiscordRequest<InviteDTO>(
            method: .get,
            path: "/invites/\(code)",
            query: [
                URLQueryItem(name: "with_counts", value: "true"),
                URLQueryItem(name: "with_expiration", value: "true")
            ]
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        return payload.toDomain()
    }

    public func accept(code: String) async throws -> DiscordInvite {
        var request = DiscordRequest<InviteDTO>(
            method: .post,
            path: "/invites/\(code)"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        return payload.toDomain()
    }
}

private struct InviteDTO: Decodable, Sendable {
    struct GuildDTO: Decodable, Sendable {
        var id: GuildID
        var name: String?
        var icon: String?
    }

    struct ChannelDTO: Decodable, Sendable {
        var id: ChannelID
        var name: String?
    }

    var code: String
    var guild: GuildDTO?
    var channel: ChannelDTO?
    var approximateMemberCount: Int?
    var approximatePresenceCount: Int?
    var expiresAt: Date?

    func toDomain() -> DiscordInvite {
        DiscordInvite(
            code: code,
            guildID: guild?.id,
            guildName: guild?.name,
            guildIconHash: guild?.icon,
            channelID: channel?.id,
            channelName: channel?.name,
            memberCount: approximateMemberCount,
            onlineCount: approximatePresenceCount,
            expiresAt: expiresAt
        )
    }
}
