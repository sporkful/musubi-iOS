// MusubiModel.swift

import Foundation

// namespaces
extension Musubi {
    struct Model {
        private init() { }
    }
}

protocol MusubiGlobalObject: Codable { }
extension Musubi.Model.Commit: MusubiGlobalObject { }
extension Musubi.Model.Blob: MusubiGlobalObject { }

extension Musubi.Model {
    // Hashable conformance here is only for SwiftUI List materialization,
    // NOT FOR STABLE ID ACROSS APP RUNS - for that, use `Musubi::Cryptography::hash`.
    struct Commit: Hashable {
        let authorID: Spotify.ID
        let date: Date
        let message: String
        
        let parentCommitIDs: [String]
        
        let blobID: String
        
//        var isVisible: Bool
    }
    
    typealias Blob = String  // instead of [UInt8] for easier JSON ser/de.
}

extension Musubi.Model.Blob {
    static func from(audioTrackList: Musubi.ViewModel.AudioTrackList) -> Self {
        return audioTrackList
            .map({ item in item.audioTrack.id })
            .joined(separator: ",")
    }
}

// TODO: is there a better way to do this (enforce date en/decoding as iso8601)
extension Musubi {
    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension Musubi.Model.Commit: CustomStringConvertible {
    var description: String {
        """
        Musubi.Model.Commit
            authorID: \(self.authorID)
            date: \(self.date.formatted())
            message: \(self.message)
            parentCommitIDs: \(self.parentCommitIDs.joined(separator: ", "))
            blobID: \(self.blobID)
        """
    }
}
