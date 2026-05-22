import Foundation
import DiscordPrimitives

public struct DiscordResponse<Value>: Sendable where Value: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var eTag: ETag?
    public var value: Value

    public init(statusCode: Int, headers: [String: String], eTag: ETag? = nil, value: Value) {
        self.statusCode = statusCode
        self.headers = headers
        self.eTag = eTag
        self.value = value
    }
}

