// Storage.swift

import Foundation

// namespaces
extension Musubi {
    struct Storage {
        private init() {}
        
        struct Keychain {
            private init() {}
        }
        
        struct LocalFS {
            private init() {}
        }
        
        struct Cloud {
            private init() {}
        }
    }
}

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

extension Musubi.Storage.LocalFS {
    static var BASE_DIR: URL {
        URL.libraryDirectory.appending(path: "MusubiLocal", directoryHint: .isDirectory)
    }
    
    static var GLOBAL_OBJECTS_DIR: URL {
        BASE_DIR.appending(path: "GlobalObjects", directoryHint: .isDirectory)
    }
    
    static func USER_CLONES_DIR(userID: Spotify.ID) -> URL {
        BASE_DIR
            .appending(path: "Users", directoryHint: .isDirectory)
            .appending(path: userID, directoryHint: .isDirectory)
            .appending(path: "Clones", directoryHint: .isDirectory)
    }
    
    static func CLONE_DIR(userID: Spotify.ID, playlistID: Spotify.ID) -> URL {
        USER_CLONES_DIR(userID: userID)
            .appending(path: playlistID, directoryHint: .isDirectory)
    }
}

extension Musubi.Storage.LocalFS {
    static func doesDirExist(at dirURL: URL) -> Bool {
        return (try? dirURL.checkResourceIsReachable()) ?? false
            && (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
    
    static func createNewDir(at dirURL: URL, withIntermediateDirectories: Bool) throws {
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: withIntermediateDirectories)
    }
    
    static func contentsOf(dirURL: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
    }
    
    static func doesFileExist(at fileURL: URL) -> Bool {
        return (try? fileURL.checkResourceIsReachable()) ?? false
            && (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }
}

extension Musubi.Storage.LocalFS {
    static func saveGlobalObject<T: MusubiGlobalObject>(object: T, objectID: String) throws {
        // TODO: 
    }
}
