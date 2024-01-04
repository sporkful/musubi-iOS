// Storage.swift

import Foundation

// TODO: a lot of repetition of userID, maybe make these all instance methods as part of a context
// (instantiated at sign-in time) instead of independent static methods?

extension Musubi {
    static func save<T: Codable>(object: T, objectID: String, userID: Spotify.ID) throws {
        try LocalStorage.save(object: object, objectID: objectID, userID: userID)
        // TODO: remote save
        // TODO: make atomic?
    }
    
    static func retrieve<T: Codable>(objectID: String, userID: Spotify.ID) throws -> T {
        return try LocalStorage.retrieve(objectID: objectID, userID: userID)
        // TODO: if local retrieve fails, try remote retrieve
    }
    
    // should only be called once, when this device is first signed into a new Spotify account.
    static func createNewStorage(userID: Spotify.ID) throws {
        try LocalStorage.createDirs(userID: userID)
        // TODO: create remote storage
    }
}

extension Musubi {
    private struct LocalStorage {
        private init() {}
        
        // template = "baseDir/userID/{repos or commits or stage}/objectID
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
                case is Model.Repository.Type: reposDirName
                case is Model.Commit.Type: commitsDirName
                case is Model.Playlist.Type: stageDirName
                default: throw StorageError.local(detail: "objectURL - unrecognized object type")
            }
            return baseDirURL
                .appending(path: userID, directoryHint: .isDirectory)
                .appending(path: dirName, directoryHint: .isDirectory)
                .appending(path: objectID, directoryHint: .notDirectory)
        }
        
        static func save<T: Codable>(object: T, objectID: String, userID: Spotify.ID) throws {
            let objectData = try JSONEncoder().encode(object)
            try objectData.write(
                to: LocalStorage.objectURL(type: T.self, objectID: objectID, userID: userID),
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
}

extension Musubi {
    private struct RemoteStorage {
        private init() {}
    }
}
