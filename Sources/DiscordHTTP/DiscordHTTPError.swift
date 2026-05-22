import Foundation

public enum DiscordHTTPError: Error, Sendable, Hashable {
    case invalidURL(String)
    case encodingFailed(String)
    case transportFailed(String)
    case badStatus(Int, Data)
    case decodingFailed(String)
    case cancelled
}

extension DiscordHTTPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidURL(value):
            return "The Discord request URL was invalid: \(value)"
        case let .encodingFailed(reason):
            return "The Discord request body could not be encoded: \(reason)"
        case let .transportFailed(reason):
            return "The network request to Discord failed: \(reason)"
        case let .badStatus(statusCode, data):
            if let summary = DiscordHTTPErrorSummary.describe(data, statusCode: statusCode) {
                return summary
            }
            return "Discord rejected the request with HTTP \(statusCode)."
        case let .decodingFailed(reason):
            return "The Discord response could not be decoded: \(reason)"
        case .cancelled:
            return "The Discord request was cancelled."
        }
    }
}

private enum DiscordHTTPErrorSummary {
    static func describe(_ data: Data, statusCode: Int) -> String? {
        if let payload = try? HTTPRuntime.makeDecoder().decode(DiscordAPIErrorPayload.self, from: data) {
            let details = validationDetails(in: data)
            let base = if let code = payload.code {
                "Discord rejected the request with HTTP \(statusCode): \(payload.message) (Discord code \(code))"
            } else {
                "Discord rejected the request with HTTP \(statusCode): \(payload.message)"
            }

            if let details, !details.isEmpty {
                return "\(base): \(details)"
            }
            return base
        }

        return nil
    }

    static func validationDetails(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errors = object["errors"] else {
            return nil
        }

        let details = flatten(errors)
        guard !details.isEmpty else {
            return nil
        }
        return details.joined(separator: "; ")
    }

    static func flatten(_ value: Any, path: [String] = []) -> [String] {
        if let array = value as? [[String: Any]] {
            return array.compactMap { entry in
                guard let message = entry["message"] as? String else {
                    return nil
                }
                if path.isEmpty {
                    return message
                }
                return "\(path.joined(separator: ".")): \(message)"
            }
        }

        guard let dictionary = value as? [String: Any] else {
            return []
        }

        var details = [String]()
        if let directErrors = dictionary["_errors"] {
            details.append(contentsOf: flatten(directErrors, path: path))
        }

        for key in dictionary.keys.sorted() where key != "_errors" {
            details.append(contentsOf: flatten(dictionary[key] as Any, path: path + [key]))
        }

        return details
    }
}
