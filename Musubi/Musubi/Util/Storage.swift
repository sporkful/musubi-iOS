// Storage.swift

import Foundation

// TODO: a lot of repetition of userID, maybe wrap these static functions as methods of the user
// instance / view model?

// namespaces
extension Musubi {
    struct Storage {
        private init() {}
        
        struct Keychain {
            private init() {}
        }
        
        struct Local {
            private init() {}
        }
        
        struct Remote {
            private init() {}
        }
    }
}

extension Musubi.Storage.Keychain {
    enum KeyName: String {
        case oauthToken, oauthRefreshToken, oauthExpirationDate
        
        var fullIdentifier: Data {
            "com.musubi-app.keys.\(self.rawValue)".data(using: .utf8)!
        }
    }
    
    static func save(keyName: KeyName, value: Data) throws {
        do {
            try update(keyName: keyName, value: value)
        } catch Musubi.StorageError.keychain {
            try insert(keyName: keyName, value: value)
        }
    }
    
    static func retrieve(keyName: KeyName) throws -> Data {
        let query = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyName.fullIdentifier,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess else {
            throw Musubi.StorageError.keychain(detail: "failed to retrieve \(keyName.rawValue)")
        }
        return result as! Data
    }
    
    static func delete(keyName: KeyName) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyName.fullIdentifier
        ] as CFDictionary

        let status = SecItemDelete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Musubi.StorageError.keychain(detail: "failed to delete \(keyName.rawValue)")
        }
    }
    
    private static func insert(keyName: KeyName, value: Data) throws {
        let attributes = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyName.fullIdentifier,
            kSecValueData: value
        ] as CFDictionary

        let status = SecItemAdd(attributes, nil)
        guard status == errSecSuccess else {
//            if status == errSecDuplicateItem {
//                throw Musubi.StorageError.keychain(detail: "\(keyName.rawValue) already exists")
//            }
            throw Musubi.StorageError.keychain(detail: "failed to insert \(keyName.rawValue)")
        }
    }
    
    private static func update(keyName: KeyName, value: Data) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
//            kSecAttrService: service,
            kSecAttrAccount: keyName.fullIdentifier
        ] as CFDictionary

        let attributes = [
            kSecValueData: value
        ] as CFDictionary

        let status = SecItemUpdate(query, attributes)
        guard status == errSecSuccess else {
//            if status == errSecItemNotFound {
//                throw Musubi.StorageError.keychain(detail: "update nonexistent \(keyName.rawValue)")
//            }
            throw Musubi.StorageError.keychain(detail: "failed to update \(keyName.rawValue)")
        }
    }
}

extension Musubi.Storage.Local {
    // Hierarchy: `baseDir/userID/{repos or commits or stage}/objectID`
    private static let baseDirURL = URL.libraryDirectory.appending(
        path: "MusubiLocalStorage",
        directoryHint: .isDirectory
    )
    private static let reposDirName = "repos"
    private static let commitsDirName = "commits"
    private static let stageDirName = "stage"
    
    private static func objectURL<T>(
        type: T.Type,
        objectID: String,
        userID: Spotify.ID
    ) throws -> URL {
        let dirName = switch type {
            case is Musubi.Model.Repository.Type: reposDirName
            case is Musubi.Model.Commit.Type: commitsDirName
            case is Musubi.Model.Playlist.Type: stageDirName
            default:
                throw Musubi.StorageError.local(detail: "objectURL - unrecognized object type")
        }
        return baseDirURL
            .appending(path: userID, directoryHint: .isDirectory)
            .appending(path: dirName, directoryHint: .isDirectory)
            .appending(path: objectID, directoryHint: .notDirectory)
    }
    
    static func save<T: Codable>(object: T, objectID: String, userID: Spotify.ID) throws {
        let objectData = try JSONEncoder().encode(object)
        try objectData.write(
            to: objectURL(type: T.self, objectID: objectID, userID: userID),
            options: .atomic
        )
    }
    
    static func retrieve<T: Codable>(objectID: String, userID: Spotify.ID) throws -> T {
        return try JSONDecoder().decode(
            T.self,
            from: Data(contentsOf: objectURL(type: T.self, objectID: objectID, userID: userID))
        )
    }
    
    static func createDirs(userID: Spotify.ID) throws {
        try FileManager.default.createDirectory(
            at: baseDirURL,
            withIntermediateDirectories: false
        )
        try FileManager.default.createDirectory(
            at: baseDirURL.appending(path: userID),
            withIntermediateDirectories: false
        )
        try FileManager.default.createDirectory(
            at: baseDirURL.appending(path: userID).appending(path: reposDirName),
            withIntermediateDirectories: false
        )
        try FileManager.default.createDirectory(
            at: baseDirURL.appending(path: userID).appending(path: commitsDirName),
            withIntermediateDirectories: false
        )
        try FileManager.default.createDirectory(
            at: baseDirURL.appending(path: userID).appending(path: stageDirName),
            withIntermediateDirectories: false
        )
    }
}

extension Musubi.Storage.Remote {
}
