// Storage.swift

import Foundation

extension Musubi {
    static func save<T: Codable>(object: T, id: String) throws {
        try LocalStorage.save(object: object, id: id)
        // TODO: remote save
        // TODO: make atomic?
    }
    
    static func retrieve<T: Codable>(id: String) throws -> T {
        return try LocalStorage.retrieve(id: id)
        // TODO: if local retrieve fails, try remote retrieve
    }
    
    static func createStorage() throws {
        try LocalStorage.createDirs()
        // TODO: create remote storage
    }
}

extension Musubi {
    private struct LocalStorage {
        private init() {}
        
        private static let baseDirURL = URL.libraryDirectory.appending(
            path: "MusubiLocalStorage",
            directoryHint: .isDirectory
        )
        
        private static let reposDirName = "repos"
        private static let commitsDirName = "commits"
        private static let stageDirName = "stage"
        
        private static func objectURL<T>(type: T.Type, id: String) throws -> URL {
            let dirName = switch type {
                case is Model.Repository.Type: reposDirName
                case is Model.Commit.Type: commitsDirName
                case is Model.Playlist.Type: stageDirName
                default: throw StorageError.local(detail: "objectURL - unrecognized object type")
            }
            return baseDirURL
                .appending(path: dirName, directoryHint: .isDirectory)
                .appending(path: id, directoryHint: .notDirectory)
        }
        
        static func save<T: Codable>(object: T, id: String) throws {
            let objectData = try JSONEncoder().encode(object)
            try objectData.write(
                to: LocalStorage.objectURL(type: T.self, id: id),
                options: .atomic
            )
        }
        
        static func retrieve<T: Codable>(id: String) throws -> T {
            return try JSONDecoder().decode(
                T.self,
                from: Data(contentsOf: objectURL(type: T.self, id: id))
            )
        }
        
        static func createDirs() throws {
            try FileManager.default.createDirectory(
                at: baseDirURL,
                withIntermediateDirectories: false
            )
            try FileManager.default.createDirectory(
                at: baseDirURL.appending(path: reposDirName),
                withIntermediateDirectories: false
            )
            try FileManager.default.createDirectory(
                at: baseDirURL.appending(path: commitsDirName),
                withIntermediateDirectories: false
            )
            try FileManager.default.createDirectory(
                at: baseDirURL.appending(path: stageDirName),
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
