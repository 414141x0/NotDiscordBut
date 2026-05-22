import CryptoKit
import Foundation
import Security
import DiscordPrimitives

public final class RemoteAuthKeyMaterial: @unchecked Sendable {
    private let privateKey: SecKey
    private let publicKey: SecKey

    public init() throws(AuthError) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw .security(error?.takeRetainedValue().localizedDescription ?? "failed to create RSA key")
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw .security("failed to derive public key")
        }

        self.privateKey = privateKey
        self.publicKey = publicKey
    }

    public func bootstrap() throws(AuthError) -> RemoteAuthBootstrap {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw .security(error?.takeRetainedValue().localizedDescription ?? "failed to export public key")
        }

        let encodedPublicKey = keyData.base64EncodedString()
        let fingerprintData = Data(SHA256.hash(data: keyData))
        let fingerprint = Fingerprint(rawValue: Base64URL.encode(fingerprintData))
        return RemoteAuthBootstrap(encodedPublicKey: encodedPublicKey, fingerprint: fingerprint)
    }

    public func nonceProof(from encryptedNonce: String) throws(AuthError) -> String {
        let encrypted: Data
        do {
            encrypted = try Base64URL.decode(encryptedNonce.replacingOccurrences(of: "=", with: ""))
        } catch {
            throw .invalidRemoteAuthMaterial("invalid encrypted nonce")
        }

        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionOAEPSHA256,
            encrypted as CFData,
            &error
        ) as Data? else {
            throw .security(error?.takeRetainedValue().localizedDescription ?? "failed to decrypt nonce")
        }

        return Base64URL.encode(decrypted)
    }
}

