import Foundation
import DiscordPrimitives

public actor GatewayRuntime {
    private var context: GatewaySessionContext
    private let identifyProperties: GatewayIdentifyProperties

    public init(
        context: GatewaySessionContext = .empty,
        identifyProperties: GatewayIdentifyProperties = GatewayIdentifyProperties(
            os: "macOS",
            browser: "NotDiscordBut",
            device: "NotDiscordBut"
        )
    ) {
        self.context = context
        self.identifyProperties = identifyProperties
    }

    public func sessionContext() -> GatewaySessionContext {
        context
    }

    public func makeIdentifyPayload(
        session: DiscordSession,
        capabilities: CapabilityMask,
        intents: IntentMask,
        clientState: GatewayClientState
    ) -> GatewayIdentifyPayload {
        GatewayIdentifyPayload(
            token: session.token,
            properties: identifyProperties,
            capabilities: capabilities,
            intents: intents,
            clientState: clientState
        )
    }

    public func makeResumePayload(session: DiscordSession) -> GatewayResumePayload? {
        guard
            let sessionID = context.sessionID,
            let sequence = context.lastSequenceNumber
        else {
            return nil
        }

        return GatewayResumePayload(token: session.token, sessionID: sessionID, sequence: sequence)
    }

    public func apply(_ event: GatewayEvent) {
        switch event {
        case let .ready(ready):
            context.apply(ready: ready)
        case let .readySupplemental(supplemental):
            context.apply(readySupplemental: supplemental)
        case let .authSessionChange(change):
            context.apply(authSessionChange: change)
        case .resumed, .unknown,
             .messageCreate, .messageUpdate, .messageDelete,
             .typingStart, .channelCreate, .channelUpdate, .channelDelete,
             .presenceUpdate, .relationshipAdd, .relationshipRemove,
             .messageReactionAdd, .messageReactionRemove,
             .guildMemberAdd, .guildMemberUpdate, .guildMemberRemove:
            break
        }
    }

    public func updateSequence(_ sequence: Int?) {
        context.lastSequenceNumber = sequence
    }

    public func gatewayURL(default defaultURL: URL) -> URL {
        context.resumeGatewayURL ?? defaultURL
    }
}

