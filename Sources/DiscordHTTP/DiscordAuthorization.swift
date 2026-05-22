import Foundation
import DiscordPrimitives

public enum DiscordAuthorization: Hashable, Sendable {
    case user(String)
    case bearer(String)

    @inlinable
    public var headerValue: String {
        switch self {
        case let .user(token):
            token
        case let .bearer(token):
            "Bearer \(token)"
        }
    }

    @inlinable
    public var sessionKind: SessionAuthenticationKind {
        switch self {
        case .user:
            .user
        case .bearer:
            .bearer
        }
    }
}

