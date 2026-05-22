import Foundation

public struct AnyEncodable: Encodable, Sendable {
    private let encodeValue: @Sendable (Encoder) throws -> Void

    public init<Value>(_ value: Value) where Value: Encodable & Sendable {
        encodeValue = value.encode(to:)
    }

    public func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

