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
}
