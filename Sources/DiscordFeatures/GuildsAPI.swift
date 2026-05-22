import Foundation
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public final class GuildsAPI: @unchecked Sendable {
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

    public func all() async -> [DiscordGuild] {
        let snapshot = await store.snapshot()
        return query.sidebarProjection(from: snapshot).guilds
    }

    public func sidebarProjection() async -> SidebarProjection {
        let snapshot = await store.snapshot()
        return query.sidebarProjection(from: snapshot)
    }

    public func listMembers(
        guildID: GuildID,
        limit: Int = 1000,
        after: UserID? = nil
    ) async throws -> [DiscordGuildMember] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let after {
            queryItems.append(URLQueryItem(name: "after", value: after.rawValue))
        }

        var request = DiscordRequest<[DiscordFeatureGuildMemberFullDTO]>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/members",
            query: queryItems
        )
        request.authorization = await authorization()

        let payloads = try await http.execute(request).value
        var users = [DiscordUser]()
        var members = [DiscordGuildMember]()
        for payload in payloads {
            guard let mapped = payload.toDomain(guildID: guildID) else { continue }
            members.append(mapped.member)
            if let user = mapped.user { users.append(user) }
        }

        try await store.apply(.merge(StateMergeSnapshot(users: users, guildMembers: members)))
        return members
    }

    public func searchMembers(
        guildID: GuildID,
        query searchQuery: String,
        limit: Int = 100
    ) async throws -> [DiscordGuildMember] {
        var request = DiscordRequest<[DiscordFeatureGuildMemberFullDTO]>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/members/search",
            query: [
                URLQueryItem(name: "query", value: searchQuery),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
        request.authorization = await authorization()

        let payloads = try await http.execute(request).value
        var users = [DiscordUser]()
        var members = [DiscordGuildMember]()
        for payload in payloads {
            guard let mapped = payload.toDomain(guildID: guildID) else { continue }
            members.append(mapped.member)
            if let user = mapped.user { users.append(user) }
        }

        try await store.apply(.merge(StateMergeSnapshot(users: users, guildMembers: members)))
        return members
    }

    public func getMember(guildID: GuildID, userID: UserID) async throws -> DiscordGuildMember {
        var request = DiscordRequest<DiscordFeatureGuildMemberFullDTO>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/members/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let mapped = payload.toDomain(guildID: guildID, fallbackUserID: userID) else {
            throw DiscordHTTPError.decodingFailed("Could not map guild member payload.")
        }

        var users = [DiscordUser]()
        if let user = mapped.user { users.append(user) }
        try await store.apply(.merge(StateMergeSnapshot(users: users, guildMembers: [mapped.member])))
        return mapped.member
    }

    public func modifyMember(_ input: GuildMemberModifyInput) async throws -> DiscordGuildMember {
        struct Request: Codable, Sendable {
            var nick: String?
            var roles: [RoleID]?
            var mute: Bool?
            var deaf: Bool?
        }

        var request = DiscordRequest<DiscordFeatureGuildMemberFullDTO>(
            method: .patch,
            path: "/guilds/\(input.guildID.rawValue)/members/\(input.userID.rawValue)",
            body: AnyEncodable(Request(
                nick: input.nickname,
                roles: input.roleIDs,
                mute: input.mute,
                deaf: input.deaf
            ))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let mapped = payload.toDomain(guildID: input.guildID, fallbackUserID: input.userID) else {
            throw DiscordHTTPError.decodingFailed("Could not map modified guild member payload.")
        }

        var users = [DiscordUser]()
        if let user = mapped.user { users.append(user) }
        try await store.apply(.merge(StateMergeSnapshot(users: users, guildMembers: [mapped.member])))
        return mapped.member
    }

    public func modifySelfMember(guildID: GuildID, nickname: String?) async throws {
        struct Request: Codable, Sendable {
            var nick: String?
        }

        var request = DiscordRequest<VoidResponse>(
            method: .patch,
            path: "/guilds/\(guildID.rawValue)/members/@me",
            body: AnyEncodable(Request(nick: nickname))
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func kickMember(guildID: GuildID, userID: UserID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/guilds/\(guildID.rawValue)/members/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.guildMemberRemove(guildID: guildID, userID: userID))
    }

    public func listBans(guildID: GuildID) async throws -> [DiscordGuildBan] {
        var request = DiscordRequest<[DiscordFeatureGuildBanDTO]>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/bans"
        )
        request.authorization = await authorization()

        let payloads = try await http.execute(request).value
        var users = [DiscordUser]()
        var bans = [DiscordGuildBan]()
        for payload in payloads {
            let mapped = payload.toDomain()
            bans.append(mapped.ban)
            users.append(mapped.user)
        }

        try await store.apply(.merge(StateMergeSnapshot(users: users)))
        return bans
    }

    public func getBan(guildID: GuildID, userID: UserID) async throws -> DiscordGuildBan {
        var request = DiscordRequest<DiscordFeatureGuildBanDTO>(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/bans/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let mapped = payload.toDomain()
        try await store.apply(.merge(StateMergeSnapshot(users: [mapped.user])))
        return mapped.ban
    }

    public func banUser(_ input: GuildBanInput) async throws {
        struct Request: Codable, Sendable {
            var deleteMessageSeconds: Int?
        }

        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/guilds/\(input.guildID.rawValue)/bans/\(input.userID.rawValue)",
            body: AnyEncodable(Request(deleteMessageSeconds: input.deleteMessageSeconds))
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func unbanUser(guildID: GuildID, userID: UserID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/guilds/\(guildID.rawValue)/bans/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func modifyGuild(_ input: GuildModifyInput) async throws -> DiscordGuild {
        struct Request: Codable, Sendable {
            var name: String?
            var description: String?
        }

        struct ResponseDTO: Decodable, Sendable {
            var id: GuildID
            var name: String
            var icon: String?
            var banner: String?
            var ownerId: UserID?
            var description: String?
            var approximateMemberCount: Int?

            func toDomain() -> DiscordGuild {
                DiscordGuild(
                    id: id,
                    name: name,
                    iconHash: icon,
                    bannerHash: banner,
                    ownerID: ownerId,
                    description: description,
                    memberCount: approximateMemberCount
                )
            }
        }

        var request = DiscordRequest<ResponseDTO>(
            method: .patch,
            path: "/guilds/\(input.guildID.rawValue)",
            body: AnyEncodable(Request(name: input.name, description: input.description))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let guild = payload.toDomain()
        try await store.apply(.merge(StateMergeSnapshot(guilds: [guild])))
        return guild
    }
}
