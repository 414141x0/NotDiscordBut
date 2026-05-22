import Foundation

public struct TaggedString<Domain>: RawRepresentable, Codable, Hashable, Sendable, LosslessStringConvertible, ExpressibleByStringLiteral where Domain: Sendable {
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
}

