import Foundation
import Testing
@testable import DiscordFeatures
import DiscordPrimitives

@Test
func messageSendInputCapturesStableTypedIdentity() {
    let input = MessageSendInput(
        channelID: ChannelID(rawValue: "55"),
        content: "hello",
        nonce: MessageNonce(rawValue: "nonce-1")
    )

    #expect(input.channelID.rawValue == "55")
    #expect(input.content == "hello")
    #expect(input.nonce?.rawValue == "nonce-1")
}

@Test
func messageSendInputStoresOptionalReplyReference() {
    let input = MessageSendInput(
        channelID: ChannelID(rawValue: "55"),
        content: "hello",
        nonce: MessageNonce(rawValue: "nonce-1"),
        messageReference: MessageReferenceSendInput(
            messageID: MessageID(rawValue: "99"),
            channelID: ChannelID(rawValue: "55"),
            guildID: GuildID(rawValue: "100")
        )
    )

    #expect(input.messageReference?.messageID.rawValue == "99")
    #expect(input.messageReference?.channelID.rawValue == "55")
    #expect(input.messageReference?.guildID?.rawValue == "100")
}
