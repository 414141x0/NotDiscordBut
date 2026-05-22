import Foundation
import Testing
@testable import DiscordGateway
import DiscordHTTP
import DiscordPrimitives

@Test
func readySupplementalMergeAddsDeferredGuildData() throws {
    var context = GatewaySessionContext.empty
    context.apply(ready: GatewayReady.stub(authSessionIDHash: "session-a"))
    context.apply(readySupplemental: GatewayReadySupplemental.stub(guildID: "100"))

    #expect(context.authSessionIDHash?.rawValue == "session-a")
    #expect(context.supplementalGuildIDs.contains("100"))
}

@Test
func gatewayReadyDecodesRuntimePayloadKeys() throws {
    let data = """
    {
      "v": 9,
      "user": {
        "id": "1",
        "username": "preview"
      },
      "guilds": [],
      "relationships": [],
      "private_channels": [],
      "read_state": [],
      "session_id": "session-1",
      "resume_gateway_url": "wss://gateway.discord.gg",
      "auth_session_id_hash": "session-a"
    }
    """.data(using: .utf8)!

    let ready = try makeRuntimeDecoder().decode(GatewayReady.self, from: data)

    #expect(ready.sessionID == "session-1")
    #expect(ready.resumeGatewayURL.absoluteString == "wss://gateway.discord.gg")
    #expect(ready.authSessionIDHash == AuthSessionIDHash(rawValue: "session-a"))
}

@Test
func authSessionChangeDecodesRuntimePayloadKeys() throws {
    let data = """
    {
      "auth_session_id_hash": "session-b"
    }
    """.data(using: .utf8)!

    let change = try makeRuntimeDecoder().decode(GatewayAuthSessionChange.self, from: data)

    #expect(change.authSessionIDHash == AuthSessionIDHash(rawValue: "session-b"))
}

private func makeRuntimeDecoder() -> JSONDecoder {
    DiscordHTTP.HTTPRuntime.makeDecoder()
}
