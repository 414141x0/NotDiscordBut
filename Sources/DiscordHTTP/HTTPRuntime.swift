import Foundation

public struct DiscordHTTPConfiguration: Sendable {
    public var baseURL: URL
    public var apiVersion: Int
    public var userAgent: String
    public var timeout: TimeInterval

    public init(
        baseURL: URL = URL(string: "https://discord.com/api")!,
        apiVersion: Int = 9,
        userAgent: String = "NotDiscordBut/0.1",
        timeout: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.apiVersion = apiVersion
        self.userAgent = userAgent
        self.timeout = timeout
    }

    public var versionedBaseURL: URL {
        baseURL.appending(path: "v\(apiVersion)")
    }
}

public actor HTTPRuntime {
    private let transport: any DiscordTransport
    private let configuration: DiscordHTTPConfiguration
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rateLimits: RateLimitStore

    public init(
        transport: any DiscordTransport,
        configuration: DiscordHTTPConfiguration,
        encoder: JSONEncoder = HTTPRuntime.makeEncoder(),
        decoder: JSONDecoder = HTTPRuntime.makeDecoder(),
        rateLimits: RateLimitStore = RateLimitStore()
    ) {
        self.transport = transport
        self.configuration = configuration
        self.encoder = encoder
        self.decoder = decoder
        self.rateLimits = rateLimits
    }

    public func execute<Response>(
        _ request: DiscordRequest<Response>
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        let defaultHeaders = [
            "Accept": "application/json",
            "User-Agent": configuration.userAgent
        ]

        let response = try await transport.send(
            request,
            baseURL: configuration.versionedBaseURL,
            encoder: encoder,
            decoder: decoder,
            defaultHeaders: defaultHeaders
        )

        return response
    }

    public func rateLimitWindow(for routeKey: String) async -> RateLimitWindow? {
        await rateLimits.window(for: routeKey)
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
