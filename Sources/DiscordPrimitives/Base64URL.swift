import Foundation

public enum Base64URLError: Error, Sendable, Equatable {
    case invalidEncoding(String)
    case invalidPayload(String)
}

public enum Base64URL: Sendable {
    @inlinable
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    @inlinable
    public static func decode(_ value: String) throws -> Data {
        let remainder = value.count % 4
        let padding = remainder == 0 ? 0 : 4 - remainder
        let padded = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: padding)

        guard let data = Data(base64Encoded: padded) else {
            throw Base64URLError.invalidEncoding(value)
        }

        return data
    }
}
