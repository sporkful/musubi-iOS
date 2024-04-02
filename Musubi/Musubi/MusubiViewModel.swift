// MusubiViewModel.swift

import Foundation

// namespaces
extension Musubi {
    struct ViewModel {
        private init() { }
    }
}

extension Musubi.ViewModel {
    typealias AudioTrackList = [UIDableAudioTrack]
    
    struct UIDableAudioTrack: Identifiable {
        let audioTrack: Spotify.AudioTrack
        
        // Unique identifier to allow [UIDableAudioTrack] to be presentable as an editable SwiftUI
        // List. This is necessary since there may be repeated audio tracks within e.g. a playlist.
        // Keep in mind that this id is intended to only be stable for the (temporary) lifetime of
        // the SwiftUI List it backs.
        let id: Int
    }
}

//extension Array where Element == Musubi.ViewModel.UIDableAudioTrack {
extension Musubi.ViewModel.AudioTrackList {
    mutating func append(audioTrack: Spotify.AudioTrack) {
        self.append(Musubi.ViewModel.UIDableAudioTrack(audioTrack: audioTrack, id: self.count))
    }
    
    mutating func append(audioTrackList: [Spotify.AudioTrack]) {
        let origCount = self.count
        self.append(
            contentsOf: audioTrackList.enumerated().map { item in
                Musubi.ViewModel.UIDableAudioTrack(audioTrack: item.element, id: item.offset + origCount)
            }
        )
    }
    
    static func from(audioTrackList: [Spotify.AudioTrack]) -> Self {
        return audioTrackList.enumerated().map { item in
            Musubi.ViewModel.UIDableAudioTrack(audioTrack: item.element, id: item.offset)
        }
    }

    static func from(blob: Musubi.Model.Blob, userManager: Musubi.UserManager) async throws -> Self {
        var audioTrackList: [Spotify.AudioTrack] = []
        var numCommasSeen = 0
        var currentRangeStartIndex = blob.startIndex
        for index in blob.indices {
            if blob[index] == "," {
                numCommasSeen += 1
                if numCommasSeen % 50 == 0 {
                    audioTrackList.append(
                        contentsOf: try await SpotifyRequests.Read.audioTracks(
                            audioTrackIDs: String(blob[currentRangeStartIndex..<index]),
                            userManager: userManager
                        )
                    )
                    currentRangeStartIndex = blob.index(after: index)
                }
            }
        }
        if !(blob.last == "," && numCommasSeen % 50 == 0) {
            audioTrackList.append(
                contentsOf: try await SpotifyRequests.Read.audioTracks(
                    audioTrackIDs: String(blob[currentRangeStartIndex...]),
                    userManager: userManager
                )
            )
        }
        return Self.from(audioTrackList: audioTrackList)
    }
}

extension Array where Element == Spotify.AudioTrack {
    static func from(audioTrackList: Musubi.ViewModel.AudioTrackList) -> Self {
        return audioTrackList.map { item in item.audioTrack }
    }
}
