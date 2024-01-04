// MusubiModel.swift

import Foundation
import CryptoKit

extension Musubi.Model {
    typealias HashPointer = String
    
    static func cryptoHash<T: Encodable>(content: T) throws -> HashPointer {
        return SHA256.hash(data: try JSONEncoder().encode(content))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

extension Musubi.Model {
    struct Playlist {
        let id: Spotify.ID
        let name: String
        let description: String
        let items: [Spotify.ID]
    }
    
    // Hashable conformance here is only for SwiftUI List materialization,
    // NOT FOR STABLE ID ACROSS APP RUNS - for that, use `cryptoHash`.
    struct Commit: Codable, Hashable {
        let authorID: Spotify.ID
        let date: Date
        let message: String
        let parentCommits: [HashPointer]
        
        // content pointers
        let playlistNameHash: HashPointer
        let playlistDescriptionHash: HashPointer
        let playlistItemsHash: HashPointer
    }
    
    struct Repository: Codable {
        let playlistID: Spotify.ID
        let initialCommit: HashPointer
        let headCommits: Set<HashPointer>
        let latestSpotifySyncCommit: HashPointer
    }
}
