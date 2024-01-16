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
    struct KeyIdentifier {
        let string: String
        
        init(keyName: KeyName) {
            self.string = "com.musubi-app.keys.\(keyName.rawValue)"
        }
        
        // TODO: support multiple users?
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
