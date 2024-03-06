// MusubiModel.swift

import Foundation

extension Musubi.Model {
    typealias HashPointer = Musubi.HashPointer
    
    // Hashable conformance here is only for SwiftUI List materialization,
    // NOT FOR STABLE ID ACROSS APP RUNS - for that, use `cryptoHash`.
    struct Commit: Codable, Hashable {
        let authorID: Spotify.Model.ID
        let date: Date
        let message: String
        let nonce: UInt64
        
        let parentCommits: [HashPointer]
        
        let rootTree: HashPointer
    }
    
    struct Tree {
        let audioTrackListBlob: HashPointer
    }
    
    typealias AudioTrackList = [Spotify.Model.ID]
}
