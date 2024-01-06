// Cryptography.swift

import Foundation
import CryptoKit

extension Musubi {
    typealias HashPointer = String
    
    static func cryptoHash<T: Encodable>(content: T) throws -> HashPointer {
        return SHA256.hash(data: try JSONEncoder().encode(content))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
    
    static func pkceVerifier() throws -> String {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            throw CryptoError.pkce(detail: "failed to generate random bytes; status=\(status)")
        }
        return base64EncodeURL(bytes: randomBytes)
    }
    
    static func pkceChallenge(pkceVerifier: String) throws -> String {
        let challenge = pkceVerifier
            .data(using: .ascii)
            .map { SHA256.hash(data: $0) }
            .map { base64EncodeURL(bytes: $0) }
        
        guard let challenge = challenge else {
            throw CryptoError.pkce(detail: "failed to generate challenge")
        }
        return challenge
    }
    
    private static func base64EncodeURL<S>(bytes: S) -> String
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
