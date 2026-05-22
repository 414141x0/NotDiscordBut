import Foundation

public enum UserDomain: Sendable {}
public enum GuildDomain: Sendable {}
public enum ChannelDomain: Sendable {}
public enum MessageDomain: Sendable {}
public enum ThreadDomain: Sendable {}
public enum RoleDomain: Sendable {}

public typealias UserID = DiscordID<UserDomain>
public typealias GuildID = DiscordID<GuildDomain>
public typealias ChannelID = DiscordID<ChannelDomain>
public typealias MessageID = DiscordID<MessageDomain>
public typealias ThreadID = DiscordID<ThreadDomain>
public typealias RoleID = DiscordID<RoleDomain>

public enum MessageNonceDomain: Sendable {}
public enum FingerprintDomain: Sendable {}
public enum AuthSessionHashDomain: Sendable {}
public enum SessionTicketDomain: Sendable {}
public enum RemoteAuthTicketDomain: Sendable {}
public enum CursorDomain: Sendable {}
public enum ETagDomain: Sendable {}

public typealias MessageNonce = TaggedString<MessageNonceDomain>
public typealias Fingerprint = TaggedString<FingerprintDomain>
public typealias AuthSessionIDHash = TaggedString<AuthSessionHashDomain>
public typealias SessionTicket = TaggedString<SessionTicketDomain>
public typealias RemoteAuthTicket = TaggedString<RemoteAuthTicketDomain>
public typealias Cursor = TaggedString<CursorDomain>
public typealias ETag = TaggedString<ETagDomain>

public extension MessageNonce {
    static func generated(
        timestamp: Date = .now,
        randomBits: UInt64? = nil
    ) -> MessageNonce {
        let milliseconds = UInt64((timestamp.timeIntervalSince1970 * 1_000).rounded())
        let entropy = randomBits ?? UInt64.random(in: 0..<(1 << 22))
        return MessageNonce(rawValue: String((milliseconds << 22) | (entropy & ((1 << 22) - 1))))
    }
}

public enum SessionAuthenticationKind: String, Codable, Sendable, CaseIterable {
    case user
    case bearer
}

public struct DiscordSession: Codable, Hashable, Sendable {
    public var userID: UserID?
    public var authKind: SessionAuthenticationKind
    public var token: String
    public var authSessionIDHash: AuthSessionIDHash?
    public var resumeGatewayURL: URL?

    public init(
        userID: UserID?,
        authKind: SessionAuthenticationKind,
        token: String,
        authSessionIDHash: AuthSessionIDHash? = nil,
        resumeGatewayURL: URL? = nil
    ) {
        self.userID = userID
        self.authKind = authKind
        self.token = token
        self.authSessionIDHash = authSessionIDHash
        self.resumeGatewayURL = resumeGatewayURL
    }
}
