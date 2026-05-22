import Foundation
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public final class UsersAPI: @unchecked Sendable {
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

    public func currentUser() async -> DiscordUser? {
        let snapshot = await store.snapshot()
        return snapshot.users.values.sorted { $0.id < $1.id }.first
    }

    public func updateProfile(
        globalName: String? = nil,
        bio: String? = nil,
        pronouns: String? = nil
    ) async throws -> DiscordUser {
        struct Request: Codable, Sendable {
            var globalName: String?
            var bio: String?
            var pronouns: String?
        }

        struct ResponseDTO: Decodable, Sendable {
            var id: UserID
            var username: String
            var discriminator: String?
            var globalName: String?
            var avatar: String?
            var banner: String?
            var accentColor: Int?
            var bot: Bool?

            func toDomain() -> DiscordUser {
                DiscordUser(
                    id: id,
                    username: username,
                    discriminator: discriminator ?? "0",
                    globalName: globalName,
                    avatarHash: avatar,
                    bannerHash: banner,
                    accentColor: accentColor,
                    bot: bot ?? false
                )
            }
        }

        var request = DiscordRequest<ResponseDTO>(
            method: .patch,
            path: "/users/@me",
            body: AnyEncodable(Request(globalName: globalName, bio: bio, pronouns: pronouns))
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        let user = payload.toDomain()
        try await store.apply(.merge(StateMergeSnapshot(users: [user])))
        return user
    }

    public func getNote(for userID: UserID) async throws -> DiscordUserNote? {
        struct ResponseDTO: Decodable, Sendable {
            var note: String?
        }

        var request = DiscordRequest<ResponseDTO>(
            method: .get,
            path: "/users/@me/notes/\(userID.rawValue)"
        )
        request.authorization = await authorization()

        let payload = try await http.execute(request).value
        guard let noteText = payload.note, !noteText.isEmpty else { return nil }
        let note = DiscordUserNote(userID: userID, note: noteText)
        try await store.apply(.userNoteUpdate(note))
        return note
    }

    public func setNote(for userID: UserID, note: String) async throws {
        struct Request: Codable, Sendable {
            var note: String
        }

        var request = DiscordRequest<VoidResponse>(
            method: .put,
            path: "/users/@me/notes/\(userID.rawValue)",
            body: AnyEncodable(Request(note: note))
        )
        request.authorization = await authorization()

        _ = try await http.execute(request)
        try await store.apply(.userNoteUpdate(DiscordUserNote(userID: userID, note: note)))
    }
}
