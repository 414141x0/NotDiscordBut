import DiscordKit
import Foundation
import Observation

@MainActor
@Observable
final class ComposerModel {
    var selectedChannelID: ChannelID?
    var draft = ""
    var isSending = false
    var errorMessage: String?
    var replyTarget: MessageReplyTarget?
    var hasAttachments = false

    var canSend: Bool {
        selectedChannelID != nil
            && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachments)
            && !isSending
    }

    func prepareForChannel(_ channelID: ChannelID?) {
        if selectedChannelID != channelID {
            replyTarget = nil
        }
        selectedChannelID = channelID
        errorMessage = nil
    }

    func beginReply(_ target: MessageReplyTarget) {
        replyTarget = target
        errorMessage = nil
    }

    func cancelReply() {
        replyTarget = nil
    }

    func makeSendInput(nonce: MessageNonce, attachments: [MessageAttachmentInput] = []) -> MessageSendInput? {
        guard let selectedChannelID else {
            return nil
        }

        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || !attachments.isEmpty else {
            return nil
        }

        return MessageSendInput(
            channelID: selectedChannelID,
            content: content,
            nonce: nonce,
            messageReference: replyTarget.map { target in
                MessageReferenceSendInput(
                    messageID: target.messageID,
                    channelID: target.channelID,
                    guildID: target.guildID
                )
            },
            attachments: attachments
        )
    }

    func markSending() {
        isSending = true
        errorMessage = nil
    }

    func finishSending() {
        isSending = false
        draft = ""
        replyTarget = nil
        hasAttachments = false
    }

    func fail(_ error: some Error) {
        isSending = false
        if let localized = (error as? LocalizedError)?.errorDescription {
            errorMessage = localized
        } else {
            errorMessage = String(describing: error)
        }
    }
}
