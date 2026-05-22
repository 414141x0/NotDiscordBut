import Foundation
import DiscordPrimitives

public struct DiscordConfiguration: Sendable {
    public var httpBaseURL: URL
    public var gatewayURL: URL
    public var remoteAuthGatewayURL: URL
    public var apiVersion: Int
    public var capabilities: CapabilityMask
    public var intents: IntentMask
    public var applicationSupportURL: URL

    public init(
        httpBaseURL: URL = URL(string: "https://discord.com/api")!,
        gatewayURL: URL = URL(string: "wss://gateway.discord.gg")!,
        remoteAuthGatewayURL: URL = URL(string: "wss://remote-auth-gateway.discord.gg/?v=2")!,
        apiVersion: Int = 9,
        capabilities: CapabilityMask = .clientCoreDefault,
        intents: IntentMask = .clientCoreDefault,
        applicationSupportURL: URL
    ) {
        self.httpBaseURL = httpBaseURL
        self.gatewayURL = gatewayURL
        self.remoteAuthGatewayURL = remoteAuthGatewayURL
        self.apiVersion = apiVersion
        self.capabilities = capabilities
        self.intents = intents
        self.applicationSupportURL = applicationSupportURL
    }
}

