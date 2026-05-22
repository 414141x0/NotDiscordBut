import Foundation
import DiscordHTTP

public enum AuthError: Error, Sendable, Hashable {
    case http(DiscordHTTPError)
    case missingTicket
    case missingToken
    case sessionUnavailable
    case invalidRemoteAuthMaterial(String)
    case security(String)
    case storage(String)
}

extension AuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .http(error):
            return error.errorDescription
        case .missingTicket:
            return "Discord did not return the MFA ticket required to continue login."
        case .missingToken:
            return "Discord did not return an authentication token."
        case .sessionUnavailable:
            return "No authenticated Discord session is available."
        case let .invalidRemoteAuthMaterial(reason):
            return "Remote authentication could not be prepared: \(reason)"
        case let .security(reason):
            return "A security operation failed: \(reason)"
        case let .storage(reason):
            return "Local session storage failed: \(reason)"
        }
    }
}
