// Storage.swift

import Foundation

// Hierarchy:
//      appDir/userID/repoPlaylistID/
//          objects/
//          refs/remotes/
//          HEAD
//          index

extension Musubi.Storage.Keychain {
    struct KeyIdentifier {
        let string: String
        
        init(keyName: KeyName) {
            self.string = "com.musubi-app.keys.\(keyName.rawValue)"
        }
        
        // TODO: support multiple concurrent users?
        // complicated by fact that we don't get user id until after successful oauth login
//        init(keyName: KeyName, userID: Spotify.ID) {
//            self.string = "com.musubi-app.keys.\(userID).\(keyName.rawValue)"
//        }
        
        enum KeyName: String {
            case oauthToken, oauthRefreshToken, oauthExpirationDate
        }
    }
    
    static func save(keyIdentifier: KeyIdentifier, value: Data) throws {
        do {
            try update(keyIdentifier: keyIdentifier, value: value)
        } catch Musubi.StorageError.keychain {
            try insert(keyIdentifier: keyIdentifier, value: value)
        }
    }
    
    static func retrieve(keyIdentifier: KeyIdentifier) throws -> Data {
        let query = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyIdentifier.string,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess else {
            throw Musubi.StorageError.keychain(detail: "failed to retrieve \(keyIdentifier.string)")
        }
        return result as! Data
    }
    
    static func delete(keyIdentifier: KeyIdentifier) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyIdentifier.string
        ] as CFDictionary

        let status = SecItemDelete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Musubi.StorageError.keychain(detail: "failed to delete \(keyIdentifier.string)")
        }
    }
    
    private static func insert(keyIdentifier: KeyIdentifier, value: Data) throws {
        let attributes = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyIdentifier.string,
            kSecValueData: value
        ] as CFDictionary

        let status = SecItemAdd(attributes, nil)
        guard status == errSecSuccess else {
//            if status == errSecDuplicateItem {
//                throw Musubi.StorageError.keychain(detail: "\(keyName.rawValue) already exists")
//            }
            throw Musubi.StorageError.keychain(detail: "failed to insert \(keyIdentifier.string)")
        }
    }
    
    private static func update(keyIdentifier: KeyIdentifier, value: Data) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyIdentifier.string
        ] as CFDictionary

        let attributes = [
            kSecValueData: value
        ] as CFDictionary

        let status = SecItemUpdate(query, attributes)
        guard status == errSecSuccess else {
//            if status == errSecItemNotFound {
//                throw Musubi.StorageError.keychain(detail: "update nonexistent \(keyName.rawValue)")
//            }
            throw Musubi.StorageError.keychain(detail: "failed to update \(keyIdentifier.string)")
        }
    }
}

// namespaces
extension Musubi {
    struct Storage {
        private init() {}
        
        struct Local {
            private init() {}
        }
        
        struct Remote {
            private init() {}
        }
        
        struct Keychain {
            private init() {}
        }
    }
}
