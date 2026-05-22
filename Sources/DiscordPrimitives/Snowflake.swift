import Foundation

public struct Snowflake: RawRepresentable, Codable, Hashable, Sendable, Comparable, LosslessStringConvertible {
    public static let discordEpochMilliseconds: UInt64 = 1_420_070_400_000

    public let rawValue: UInt64

    @inlinable
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    @inlinable
    public init?(_ description: String) {
        guard let rawValue = UInt64(description) else {
            return nil
        }

        self.init(rawValue: rawValue)
    }

    @inlinable
    public init(
        timestamp: Date,
        worker: UInt8 = 0,
        process: UInt8 = 0,
        increment: UInt16 = 0
    ) {
        let milliseconds = UInt64((timestamp.timeIntervalSince1970 * 1_000).rounded(.towardZero))
        let timestampBits = (milliseconds - Self.discordEpochMilliseconds) << 22
        let workerBits = UInt64(worker & 0x1F) << 17
        let processBits = UInt64(process & 0x1F) << 12
        let incrementBits = UInt64(increment & 0x0FFF)

        self.rawValue = timestampBits | workerBits | processBits | incrementBits
    }

    @inlinable
    public var description: String {
        String(rawValue)
    }

    @inlinable
    public var timestamp: Date {
        let milliseconds = (rawValue >> 22) + Self.discordEpochMilliseconds
        return Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }

    @inlinable
    public var worker: UInt8 {
        UInt8((rawValue & 0x3E0000) >> 17)
    }

    @inlinable
    public var process: UInt8 {
        UInt8((rawValue & 0x1F000) >> 12)
    }

    @inlinable
    public var increment: UInt16 {
        UInt16(rawValue & 0xFFF)
    }

    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

