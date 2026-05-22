import Foundation
import Testing
@testable import DiscordPrimitives

@Test
func snowflakeTimestampRoundTripPreservesMilliseconds() throws {
    let timestamp = Date(timeIntervalSince1970: 1_700_000_000.125)
    let snowflake = Snowflake(timestamp: timestamp, worker: 7, process: 3, increment: 511)

    #expect(abs(snowflake.timestamp.timeIntervalSince1970 - timestamp.timeIntervalSince1970) < 0.001)
    #expect(snowflake.worker == 7)
    #expect(snowflake.process == 3)
    #expect(snowflake.increment == 511)
}

@Test
func base64URLRoundTripPreservesPayload() throws {
    let payload = Data([0x01, 0x02, 0xFD, 0xFE, 0xFF])
    let encoded = Base64URL.encode(payload)
    let decoded = try Base64URL.decode(encoded)

    #expect(decoded == payload)
}

@Test
func legacyMessagePayloadDecodesWithDefaultMediaFields() throws {
    let data = """
    {
      "id": "10",
      "channelID": "99",
      "authorID": "2",
      "content": "Hello",
      "timestamp": "2026-05-20T10:00:00Z",
      "flags": 0
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let message = try decoder.decode(DiscordMessage.self, from: data)

    #expect(message.memberNickname == nil)
    #expect(message.attachments.isEmpty)
    #expect(message.embeds.isEmpty)
}

@Test
func generatedMessageNonceUsesDiscordSizedNumericFormat() {
    let nonce = MessageNonce.generated(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        randomBits: 0x12345
    )

    #expect(nonce.rawValue.allSatisfy { $0.isNumber })
    #expect(nonce.rawValue.count <= 25)
    #expect(nonce.rawValue == "7130316800000074565")
}
