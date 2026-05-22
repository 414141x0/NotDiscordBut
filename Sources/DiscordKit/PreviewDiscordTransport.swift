import Foundation
import DiscordHTTP
import DiscordPrimitives

actor PreviewDiscordTransport: DiscordTransport {
    private let currentUserID: UserID

    init(currentUserID: UserID) {
        self.currentUserID = currentUserID
    }

    func send<Response>(
        _ request: DiscordRequest<Response>,
        baseURL: URL,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        defaultHeaders: [String: String]
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        switch (request.method, request.path) {
        case (.post, let path) where path.hasPrefix("/channels/") && path.hasSuffix("/messages"):
            guard let channelID = channelIdentifier(in: path) else {
                throw .transportFailed("Missing preview channel identifier")
            }
            guard let body = request.body else {
                throw .transportFailed("Missing preview message payload")
            }

            let data: Data
            do {
                data = try encoder.encode(body)
            } catch {
                throw .encodingFailed(error.localizedDescription)
            }

            let payload: PreviewMessagePayload
            do {
                payload = try decodePreviewMessagePayload(from: data)
            } catch {
                throw .decodingFailed(error.localizedDescription)
            }

            let messageID = payload.nonce?.rawValue ?? UUID().uuidString
            let formatter = ISO8601DateFormatter()
            var responseObject: [String: Any] = [
                "id": messageID,
                "channel_id": channelID.rawValue,
                "author": [
                    "id": currentUserID.rawValue,
                    "username": "preview",
                    "global_name": "Preview"
                ],
                "content": payload.content,
                "timestamp": formatter.string(from: .now),
                "type": payload.messageReference == nil ? DiscordMessageType.default.rawValue : DiscordMessageType.reply.rawValue
            ]

            if let reference = payload.messageReference {
                var referenceObject: [String: Any] = [
                    "channel_id": reference.channelID.rawValue
                ]
                if let messageID = reference.messageID?.rawValue {
                    referenceObject["message_id"] = messageID
                }
                if let guildID = reference.guildID?.rawValue {
                    referenceObject["guild_id"] = guildID
                }
                responseObject["message_reference"] = referenceObject
            }

            let responseData: Data
            do {
                responseData = try JSONSerialization.data(withJSONObject: responseObject)
            } catch {
                throw .encodingFailed(error.localizedDescription)
            }

            let value: Response
            do {
                value = try decoder.decode(Response.self, from: responseData)
            } catch {
                throw .decodingFailed(error.localizedDescription)
            }

            return DiscordResponse(statusCode: 200, headers: [:], eTag: nil, value: value)

        case (.get, let path) where path.hasPrefix("/channels/") && path.hasSuffix("/messages"):
            guard let value = [] as? Response else {
                throw .transportFailed("Preview transport could not cast empty message list")
            }
            return DiscordResponse(statusCode: 200, headers: [:], eTag: nil, value: value)

        case (.put, let path) where path.contains("/reactions/") && path.hasSuffix("/@me"),
             (.delete, let path) where path.contains("/reactions/") && path.hasSuffix("/@me"):
            guard let value = VoidResponse() as? Response else {
                throw .transportFailed("Preview transport could not cast reaction response")
            }
            return DiscordResponse(statusCode: 204, headers: [:], eTag: nil, value: value)

        case (.post, "/auth/logout"):
            guard let value = VoidResponse() as? Response else {
                throw .transportFailed("Preview transport could not cast logout response")
            }
            return DiscordResponse(statusCode: 204, headers: [:], eTag: nil, value: value)

        default:
            throw .transportFailed("Preview transport does not implement \(request.method.rawValue) \(request.path)")
        }
    }

    private func channelIdentifier(in path: String) -> ChannelID? {
        let components = path.split(separator: "/")
        guard components.count >= 3 else {
            return nil
        }
        return ChannelID(rawValue: String(components[1]))
    }

    private func decodePreviewMessagePayload(from data: Data) throws -> PreviewMessagePayload {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DiscordHTTPError.decodingFailed("Preview message payload was not a JSON object")
        }

        guard let content = json["content"] as? String else {
            throw DiscordHTTPError.decodingFailed("Preview message payload is missing content")
        }

        let nonce = (json["nonce"] as? String).map { MessageNonce(rawValue: $0) }
        let messageReference = previewMessageReference(from: json["message_reference"])

        return PreviewMessagePayload(
            content: content,
            nonce: nonce,
            messageReference: messageReference
        )
    }

    private func previewMessageReference(from value: Any?) -> DiscordMessageReference? {
        guard let value,
              let reference = value as? [String: Any],
              let channelID = reference["channel_id"] as? String else {
            return nil
        }

        let messageID = (reference["message_id"] as? String).map { MessageID(rawValue: $0) }
        let guildID = (reference["guild_id"] as? String).map { GuildID(rawValue: $0) }
        return DiscordMessageReference(
            messageID: messageID,
            channelID: ChannelID(rawValue: channelID),
            guildID: guildID
        )
    }
}

private struct PreviewMessagePayload: Sendable {
    var content: String
    var nonce: MessageNonce?
    var messageReference: DiscordMessageReference?
}
