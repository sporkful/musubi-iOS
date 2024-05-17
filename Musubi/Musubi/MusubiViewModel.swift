// MusubiViewModel.swift

import Foundation

// namespaces
extension Musubi {
    struct ViewModel {
        private init() { }
        
        enum Error: LocalizedError {
            case misc(detail: String)
            case DEV(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .misc(detail): "(misc) \(detail)"
                    case let .DEV(detail): "(DEV) \(detail)"
                }
                return "[Musubi::ViewModel] \(description)"
            }
        }
    }
}

extension Musubi.ViewModel {
    @Observable
    @MainActor
    class AudioTrackList {
        private(set) var contents: [UniquifiedElement]
        
        private var audioTrackCounter: [Spotify.ID : Int]
        private var audioTrackData: [Spotify.ID : Spotify.AudioTrack]
        
        struct UniquifiedElement: Identifiable, Equatable, Hashable {
            let audioTrackID: Spotify.ID
            let occurrence: Int  // per-value counter starting at 1
            
            weak var context: AudioTrackList?
            
            init(audioTrackID: Spotify.ID, occurrence: Int, context: AudioTrackList?) {
                self.audioTrackID = audioTrackID
                self.occurrence = occurrence
                self.context = context
            }
            
            var audioTrack: Spotify.AudioTrack? {
                get async { await self.context?.audioTrackData[audioTrackID] }
            }
            
            var id: String { "\(audioTrackID):\(occurrence)" }
            
            static func == (
                lhs: Musubi.ViewModel.AudioTrackList.UniquifiedElement,
                rhs: Musubi.ViewModel.AudioTrackList.UniquifiedElement
            ) -> Bool {
                return lhs.audioTrackID == rhs.audioTrackID
                    && lhs.occurrence == rhs.occurrence
                    && lhs.context === rhs.context
            }
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(audioTrackID)
                hasher.combine(occurrence)
            }
        }
        
        init(audioTracks: [Spotify.AudioTrack]) {
            self.contents = []
            self.audioTrackCounter = [:]
            self.audioTrackData = [:]
            
            self._append(audioTracks: audioTracks)
        }
        
        func append(audioTracks: [Spotify.AudioTrack]) async {
            self._append(audioTracks: audioTracks)
        }
        
        private func _append(audioTracks: [Spotify.AudioTrack]) {
            for audioTrack in audioTracks {
                if self.audioTrackData[audioTrack.id] == nil {
                    self.audioTrackData[audioTrack.id] = audioTrack
                }
                self.audioTrackCounter[audioTrack.id] = (self.audioTrackCounter[audioTrack.id] ?? 0) + 1
                self.contents.append(
                    UniquifiedElement(
                        audioTrackID: audioTrack.id,
                        occurrence: self.audioTrackCounter[audioTrack.id]!,
                        context: self
                    )
                )
            }
            assert(Set(self.contents).count == self.contents.count, "[Musubi::ViewModel] _append failed to uniquify")
        }
        
        func remove(at index: Int) async -> Spotify.ID {
            let removedElement = self.contents.remove(at: index)
            self.contents.indices.forEach { i in
                if self.contents[i].audioTrackID == removedElement.audioTrackID
                    && self.contents[i].occurrence > removedElement.occurrence
                {
                    self.contents[i] = UniquifiedElement(
                        audioTrackID: self.contents[i].audioTrackID,
                        occurrence: self.contents[i].occurrence - 1,
                        context: self.contents[i].context
                    )
                }
            }
            assert(Set(self.contents).count == self.contents.count, "[Musubi::ViewModel] remove failed to uniquify")
            return removedElement.audioTrackID
        }
        
        func move(fromOffsets source: IndexSet, toOffset destination: Int) async {
            self.contents.move(fromOffsets: source, toOffset: destination)
            
            var recounter: [Spotify.ID : Int] = [:]
            for (i, element) in self.contents.enumerated() {
                recounter[element.audioTrackID] = (recounter[element.audioTrackID] ?? 0) + 1
                if element.occurrence != recounter[element.audioTrackID]! {
                    self.contents[i] = UniquifiedElement(
                        audioTrackID: element.audioTrackID,
                        occurrence: recounter[element.audioTrackID]!,
                        context: element.context
                    )
                }
            }
            
            assert(Set(self.contents).count == self.contents.count, "[Musubi::ViewModel] move failed to uniquify")
            assert(recounter == self.audioTrackCounter, "[Musubi::ViewModel] move caused unstable counter")
        }
    }
}

/*

extension Musubi.ViewModel {
    typealias AudioTrackList = [UIDableAudioTrack]
    
    struct UIDableAudioTrack: Identifiable, Hashable {
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
}

extension Array where Element == Spotify.AudioTrack {
    static func from(audioTrackList: Musubi.ViewModel.AudioTrackList) -> Self {
        return audioTrackList.map { item in item.audioTrack }
    }
}

*/
