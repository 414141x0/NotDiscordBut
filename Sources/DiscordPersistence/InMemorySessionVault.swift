import Foundation
import DiscordPrimitives

public actor InMemorySessionVault: SessionVault {
    private var session: DiscordSession?

    public init(session: DiscordSession? = nil) {
        self.session = session
    }

    public func load() async throws -> DiscordSession? {
        session
    }

    public func store(_ session: DiscordSession) async throws {
        self.session = session
    }

    public func clear() async throws {
        session = nil
    }
}

