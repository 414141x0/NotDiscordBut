import Foundation
import DiscordPrimitives

public struct GatewaySessionContext: Codable, Hashable, Sendable {
    public var authSessionIDHash: AuthSessionIDHash?
    public var resumeGatewayURL: URL?
    public var sessionID: String?
    public var lastSequenceNumber: Int?
    public var supplementalGuildIDs: Set<String>

    public init(
        authSessionIDHash: AuthSessionIDHash? = nil,
        resumeGatewayURL: URL? = nil,
        sessionID: String? = nil,
        lastSequenceNumber: Int? = nil,
        supplementalGuildIDs: Set<String> = []
    ) {
        self.authSessionIDHash = authSessionIDHash
        self.resumeGatewayURL = resumeGatewayURL
        self.sessionID = sessionID
        self.lastSequenceNumber = lastSequenceNumber
        self.supplementalGuildIDs = supplementalGuildIDs
    }

    public static let empty = GatewaySessionContext()

    public mutating func apply(ready: GatewayReady) {
        authSessionIDHash = ready.authSessionIDHash
        resumeGatewayURL = ready.resumeGatewayURL
        sessionID = ready.sessionID
    }

    public mutating func apply(readySupplemental: GatewayReadySupplemental) {
        supplementalGuildIDs.formUnion(readySupplemental.guilds.map(\.id.rawValue))
    }

    public mutating func apply(authSessionChange: GatewayAuthSessionChange) {
        authSessionIDHash = authSessionChange.authSessionIDHash
    }
}

