import Foundation
import DiscordPrimitives

public protocol DiscordTransport: Sendable {
    func send<Response>(
        _ request: DiscordRequest<Response>,
        baseURL: URL,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        defaultHeaders: [String: String]
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable
}

enum HTTPResponseDebugSummary {
    static func decodingFailureDescription(for data: Data, underlyingError: some Error) -> String {
        let base = underlyingError.localizedDescription

        guard let summary = summarize(data) else {
            return base
        }

        return "\(base) Response summary: \(summary)"
    }

    private static func summarize(_ data: Data) -> String? {
        guard !data.isEmpty else {
            return "empty body"
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return "non-JSON body (\(data.count) bytes)"
        }

        if let dictionary = object as? [String: Any] {
            let keys = dictionary.keys.sorted()
            var parts = ["keys=\(keys.joined(separator: ","))"]

            if let code = dictionary["code"] {
                parts.append("code=\(code)")
            }

            if let message = dictionary["message"] as? String {
                parts.append("message=\(message)")
            }

            return parts.joined(separator: " ")
        }

        if let array = object as? [Any] {
            return "array(count=\(array.count))"
        }

        return String(describing: type(of: object))
    }
}

public actor URLSessionDiscordTransport: DiscordTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send<Response>(
        _ request: DiscordRequest<Response>,
        baseURL: URL,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        defaultHeaders: [String: String]
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        let urlRequest = try request.makeURLRequest(baseURL: baseURL, encoder: encoder, defaultHeaders: defaultHeaders)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .transportFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .transportFailed("Expected HTTPURLResponse")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw .badStatus(httpResponse.statusCode, data)
        }

        let headers = httpResponse.value(forHTTPHeaderField: "ETag").map { ["ETag": $0] } ?? [:]
        let eTag = httpResponse.value(forHTTPHeaderField: "ETag").map(ETag.init(rawValue:))

        if Response.self == VoidResponse.self {
            return DiscordResponse(
                statusCode: httpResponse.statusCode,
                headers: headers,
                eTag: eTag,
                value: VoidResponse() as! Response
            )
        }

        do {
            let value = try decoder.decode(Response.self, from: data)
            return DiscordResponse(statusCode: httpResponse.statusCode, headers: headers, eTag: eTag, value: value)
        } catch {
            throw .decodingFailed(HTTPResponseDebugSummary.decodingFailureDescription(for: data, underlyingError: error))
        }
    }
}
