import Foundation

public struct DiscordID<Domain>: RawRepresentable, Codable, Hashable, Sendable, LosslessStringConvertible, ExpressibleByStringLiteral, Comparable where Domain: Sendable {
    public let rawValue: String

    @inlinable
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    @inlinable
    public init(_ rawValue: some StringProtocol) {
        self.rawValue = String(rawValue)
    }

    @inlinable
    public init?(_ description: String) {
        guard !description.isEmpty else {
            return nil
        }

        self.rawValue = description
    }

    @inlinable
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    @inlinable
    public var description: String {
        rawValue
    }

    @inlinable
    public var snowflake: Snowflake? {
        guard let value = UInt64(rawValue) else {
            return nil
        }

        return Snowflake(rawValue: value)
    }

    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.snowflake, rhs.snowflake) {
        case let (.some(left), .some(right)):
            return left < right
        default:
            return lhs.rawValue < rhs.rawValue
        }
    }
}

