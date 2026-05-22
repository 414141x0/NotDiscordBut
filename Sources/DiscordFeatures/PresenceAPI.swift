import Foundation
import DiscordHTTP
import DiscordPrimitives

public final class PresenceAPI: @unchecked Sendable {
    private let http: HTTPRuntime
    private let authorization: @Sendable () async -> DiscordAuthorization?

    public init(
        http: HTTPRuntime,
        authorization: @escaping @Sendable () async -> DiscordAuthorization?
    ) {
        self.http = http
        self.authorization = authorization
    }

    public func update(status: PresenceStatus) async throws {
        struct Request: Codable, Sendable {
            var status: PresenceStatus
        }

        var request = DiscordRequest<VoidResponse>(
            method: .post,
            path: "/users/@me/settings-proto/1",
            body: AnyEncodable(Request(status: status))
        )
        request.authorization = await authorization()
        _ = try await http.execute(request)
    }
}

