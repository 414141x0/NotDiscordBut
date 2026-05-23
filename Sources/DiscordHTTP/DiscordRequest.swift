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

public struct MultipartFormFile: Sendable {
    public var name: String
    public var filename: String
    public var contentType: String
    public var data: Data

    public init(name: String, filename: String, contentType: String, data: Data) {
        self.name = name
        self.filename = filename
        self.contentType = contentType
        self.data = data
    }
}

public struct DiscordRequest<Response>: Sendable where Response: Decodable & Sendable {
    public var method: DiscordHTTPMethod
    public var path: String
    public var query: [URLQueryItem]
    public var body: AnyEncodable?
    public var multipartFiles: [MultipartFormFile]
    public var authorization: DiscordAuthorization?
    public var headers: [String: String]
    public var fingerprint: Fingerprint?

    public init(
        method: DiscordHTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: AnyEncodable? = nil,
        multipartFiles: [MultipartFormFile] = [],
        authorization: DiscordAuthorization? = nil,
        headers: [String: String] = [:],
        fingerprint: Fingerprint? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.multipartFiles = multipartFiles
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

        if !multipartFiles.isEmpty {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var httpBody = Data()
            let crlf = "\r\n"

            if let body {
                do {
                    let jsonData = try encoder.encode(body)
                    httpBody.append("--\(boundary)\(crlf)".data(using: .utf8)!)
                    httpBody.append("Content-Disposition: form-data; name=\"payload_json\"\(crlf)".data(using: .utf8)!)
                    httpBody.append("Content-Type: application/json\(crlf)\(crlf)".data(using: .utf8)!)
                    httpBody.append(jsonData)
                    httpBody.append(crlf.data(using: .utf8)!)
                } catch {
                    throw .encodingFailed(error.localizedDescription)
                }
            }

            for file in multipartFiles {
                httpBody.append("--\(boundary)\(crlf)".data(using: .utf8)!)
                httpBody.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\(crlf)".data(using: .utf8)!)
                httpBody.append("Content-Type: \(file.contentType)\(crlf)\(crlf)".data(using: .utf8)!)
                httpBody.append(file.data)
                httpBody.append(crlf.data(using: .utf8)!)
            }

            httpBody.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
            request.httpBody = httpBody
        } else if let body {
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
