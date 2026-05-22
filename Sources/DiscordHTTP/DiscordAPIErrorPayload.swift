import Foundation

struct DiscordAPIErrorPayload: Decodable, Sendable, Hashable {
    var code: Int?
    var message: String
}
