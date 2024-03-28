// Cryptography.swift

import Foundation
import CryptoKit

// namespaces
extension Musubi {
    struct Cryptography {
        private init() {}
    }
}

extension Musubi.Cryptography {
    typealias HashPointer = String
    
    static func hash(data: Data) -> HashPointer {
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
    
    static func hash<T: Encodable>(jsonCodable: T) throws -> HashPointer {
        return hash(data: try JSONEncoder().encode(jsonCodable))
    }
    
    private static let pkcePossibleChars = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    )
    
    private static let pkceVerifierLength = 128
    
    static func newPKCEVerifier() -> String {
        // This is cryptographically secure on iOS devices.
        // https://forums.swift.org/t/random-data-uint8-random-or-secrandomcopybytes/56165/12
        var srng = SystemRandomNumberGenerator()
        return String(
            (0..<pkceVerifierLength).map { _ in pkcePossibleChars.randomElement(using: &srng)! }
        )
        
//        var randomBytes = [UInt8](repeating: 0, count: 32)
//        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
//        if status != errSecSuccess {
//            throw CryptographyError.pkce(detail: "failed to generate random bytes; status=\(status)")
//        }
//        return encodeBase64URL(bytes: randomBytes)
    }
    
    static func newPKCEChallenge(pkceVerifier: String) throws -> String {
        guard let pkceVerifier = pkceVerifier.data(using: .ascii) else {
            throw Musubi.CryptographyError.pkce(detail: "failed to generate challenge")
        }
        return encodeBase64URL(bytes: SHA256.hash(data: pkceVerifier))
    }
    
    private static func encodeBase64URL<S>(bytes: S) -> String
    where S : Sequence, UInt8 == S.Element
    {
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: .whitespaces)
    }
}
