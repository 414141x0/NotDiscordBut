import Foundation
import DiscordPrimitives

public enum DiscordHTTPMethod: String, Codable, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public struct VoidResponse: Codable, Sendable, Hashable {
    public init() {}
}

public struct DiscordRequest<Response>: Sendable where Response: Decodable & Sendable {
    public var method: DiscordHTTPMethod
    public var path: String
    public var query: [URLQueryItem]
    public var body: AnyEncodable?
    public var authorization: DiscordAuthorization?
    public var headers: [String: String]
    public var fingerprint: Fingerprint?

    public init(
        method: DiscordHTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: AnyEncodable? = nil,
        authorization: DiscordAuthorization? = nil,
        headers: [String: String] = [:],
        fingerprint: Fingerprint? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.authorization = authorization
        self.headers = headers
        self.fingerprint = fingerprint
    }

    func makeURLRequest(
        baseURL: URL,
        encoder: JSONEncoder,
        defaultHeaders: [String: String]
    ) throws(DiscordHTTPError) -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw .invalidURL(baseURL.absoluteString + path)
        }

        if !query.isEmpty {
            components.queryItems = query
        }

        guard let url = components.url else {
            throw .invalidURL(components.string ?? path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        for (name, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let authorization {
            request.setValue(authorization.headerValue, forHTTPHeaderField: "Authorization")
        }

        if let fingerprint {
            request.setValue(fingerprint.rawValue, forHTTPHeaderField: "X-Fingerprint")
        }

        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let body {
            do {
                request.httpBody = try encoder.encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw .encodingFailed(error.localizedDescription)
            }
        }

        return request
    }
}
