import Foundation

public struct RateLimitWindow: Codable, Hashable, Sendable {
    public var limit: Int?
    public var remaining: Int?
    public var resetAfter: TimeInterval?
    public var bucketID: String?

    public init(limit: Int? = nil, remaining: Int? = nil, resetAfter: TimeInterval? = nil, bucketID: String? = nil) {
        self.limit = limit
        self.remaining = remaining
        self.resetAfter = resetAfter
        self.bucketID = bucketID
    }
}

public actor RateLimitStore {
    private var windows: [String: RateLimitWindow] = [:]

    public init() {}

    public func record(_ window: RateLimitWindow, for routeKey: String) {
        windows[routeKey] = window
    }

    public func window(for routeKey: String) -> RateLimitWindow? {
        windows[routeKey]
    }
}

