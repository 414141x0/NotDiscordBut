import Foundation
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public final class RelationshipsAPI: @unchecked Sendable {
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

    public func all() async -> [DiscordRelationship] {
        let snapshot = await store.snapshot()
        return snapshot.relationships.values.sorted { $0.userID < $1.userID }
    }

    public func sendFriendRequest(username: String) async throws {
        struct Request: Codable, Sendable {
            var username: String
        }

        var request = DiscordRequest<VoidResponse>(
            method: .post,
            path: "/users/@me/relationships",
            body: AnyEncodable(Request(username: username))
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
    }

    public func acceptFriendRequest(userID: UserID) async throws {
        struct Request: Codable, Sendable {
            var type: Int
        }

        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/users/@me/relationships/\(userID.rawValue)",
            body: AnyEncodable(Request(type: 1))
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.relationshipAdd(DiscordRelationship(userID: userID, kind: .friend)))
    }

    public func removeRelationship(userID: UserID) async throws {
        var request = DiscordRequest<VoidResponse>(
            method: .delete,
            path: "/users/@me/relationships/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.relationshipRemove(userID))
    }

    public func blockUser(userID: UserID) async throws {
        struct Request: Codable, Sendable {
            var type: Int
        }

        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/users/@me/relationships/\(userID.rawValue)",
            body: AnyEncodable(Request(type: 2))
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.relationshipAdd(DiscordRelationship(userID: userID, kind: .blocked)))
    }
}
