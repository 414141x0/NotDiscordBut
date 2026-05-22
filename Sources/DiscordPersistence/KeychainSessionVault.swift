import Foundation
import Security
import DiscordPrimitives

public enum KeychainVaultError: Error, Sendable, Hashable {
    case unexpectedStatus(OSStatus)
    case encodingFailed(String)
    case decodingFailed(String)
}

public actor KeychainSessionVault: SessionVault {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(service: String = "disc.notdiscordbut.session", account: String = "default") {
        self.service = service
        self.account = account
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() async throws -> DiscordSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                return nil
            }

            do {
                return try decoder.decode(DiscordSession.self, from: data)
            } catch {
                throw KeychainVaultError.decodingFailed(error.localizedDescription)
            }
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainVaultError.unexpectedStatus(status)
        }
    }

    public func store(_ session: DiscordSession) async throws {
        let data: Data
        do {
            data = try encoder.encode(session)
        } catch {
            throw KeychainVaultError.encodingFailed(error.localizedDescription)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainVaultError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainVaultError.unexpectedStatus(updateStatus)
        }
    }

    public func clear() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainVaultError.unexpectedStatus(status)
        }
    }
}

