// MusubiModel.swift

import Foundation

// namespaces
extension Musubi {
    struct Model {
        private init() { }
    }
}

extension Musubi.Model {
    typealias HashPointer = Musubi.Cryptography.HashPointer
    
    // Hashable conformance here is only for SwiftUI List materialization,
    // NOT FOR STABLE ID ACROSS APP RUNS - for that, use `Musubi::Cryptography::hash`.
    struct Commit: Codable, Hashable {
        let authorID: Spotify.ID
        let date: Date
        let message: String
        let nonce: UInt64
        
        let parentCommits: [HashPointer]
        
        let rootTree: HashPointer
        
        let isVisible: Bool
    }
    
    struct Tree {
        let audioTrackListBlob: HashPointer
    }
    
    typealias AudioTrackList = [Spotify.ID]
}
