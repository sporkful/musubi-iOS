// MusubiModel.swift

import Foundation

extension Musubi.Model {
    typealias HashPointer = Musubi.HashPointer
    
    struct Repository: Codable {
        let playlistID: Spotify.ID
        
        // commit pointers
        let head: HashPointer  // only one local head since branches are merged upon discovery.
        let latestHubSync: HashPointer
        let latestSpotifySync: HashPointer
    }
    
    // Hashable conformance here is only for SwiftUI List materialization,
    // NOT FOR STABLE ID ACROSS APP RUNS - for that, use `cryptoHash`.
    struct Commit: Codable, Hashable {
        let authorID: Spotify.ID
        let date: Date
        let message: String
        let nonce: UInt64
        
        let parentCommits: [HashPointer]
        
        // content pointers
        let playlistNameHash: HashPointer
        let playlistDescriptionHash: HashPointer
        let playlistItemsHash: HashPointer
    }
    
    struct Playlist {
        let id: Spotify.ID
        let name: String
        let description: String
        let items: [Spotify.ID]
    }
}
