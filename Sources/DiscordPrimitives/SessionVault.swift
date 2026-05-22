public protocol SessionVault: Sendable {
    func load() async throws -> DiscordSession?
    func store(_ session: DiscordSession) async throws
    func clear() async throws
}

