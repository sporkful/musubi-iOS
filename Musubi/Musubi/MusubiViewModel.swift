// MusubiViewModel.swift

import Foundation

// namespaces
extension Musubi {
    struct ViewModel {
        private init() { }
    }
}

extension Musubi.ViewModel {
    @Observable
    @MainActor
    class AudioTrackList {
//        let contextType: ContextType
//        
//        enum ContextType: String {
//            case album = "Album"
//            case spotifyPlaylist = "Spotify Playlist"
//            case musubiLocalClone = "Musubi Local Clone"
//        }
        
        private(set) var contents: [UniquifiedElement]
        
        private(set) var audioTrackCounter: [Spotify.ID : Int]
        private(set) var audioTrackData: [Spotify.ID : Spotify.AudioTrack]
        
        struct UniquifiedElement: /*Identifiable,*/ Equatable, Hashable, CustomStringConvertible {
            let audioTrackID: Spotify.ID
            let occurrence: Int  // per-value counter starting at 1
            
            weak var context: AudioTrackList?
            
            // for audio tracks with no context, e.g. from search
            private var _audioTrack: Spotify.AudioTrack?
            
            var audioTrack: Spotify.AudioTrack? {
                get async {
                    if let _audioTrack = _audioTrack {
                        return _audioTrack
                    } else {
                        return await self.context?.audioTrackData[audioTrackID]
                    }
                }
            }
            
            // TODO: make context non-optional for this initializer
            init(audioTrackID: Spotify.ID, occurrence: Int, context: AudioTrackList?) {
                self.audioTrackID = audioTrackID
                self.occurrence = occurrence
                self.context = context
                self._audioTrack = nil
            }
            
            init(audioTrack: Spotify.AudioTrack) {
                self.audioTrackID = audioTrack.id
                self.occurrence = 1
                self.context = nil
                self._audioTrack = audioTrack
            }
            
//            var id: String { "\(audioTrackID):\(occurrence)" }
            
            var description: String { "(\"\(audioTrackID)\", \(occurrence))" }
            
            static func == (
                lhs: Musubi.ViewModel.AudioTrackList.UniquifiedElement,
                rhs: Musubi.ViewModel.AudioTrackList.UniquifiedElement
            ) -> Bool {
                return lhs.audioTrackID == rhs.audioTrackID
                    && lhs.occurrence == rhs.occurrence
//                    && lhs.context === rhs.context // omission for correct canonical CollectionDifference
            }
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(audioTrackID)
                hasher.combine(occurrence)
            }
        }
        
        init(audioTracks: [Spotify.AudioTrack]) throws {
            self.contents = []
            self.audioTrackCounter = [:]
            self.audioTrackData = [:]
            
            try self._append(audioTracks: audioTracks)
        }
        
        func append(audioTracks: [Spotify.AudioTrack]) async throws {
            try self._append(audioTracks: audioTracks)
        }
        
        private func _append(audioTracks: [Spotify.AudioTrack]) throws {
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
            
            if Set(self.contents).count != self.contents.count {
                throw Error.DEV(detail: "append failed to maintain uniqueness")
            }
        }
        
        func remove(at index: Int) async throws -> Spotify.ID {
            return try self._remove(at: index)
        }
        
        func remove(atOffsets offsets: IndexSet) async throws -> [Spotify.ID] {
            var removedElements: [Spotify.ID] = []
            for offset in offsets.sorted().reversed() {
                removedElements.append(try self._remove(at: offset))
            }
            return removedElements
        }
        
        func _remove(at index: Int) throws -> Spotify.ID {
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
            
            if Set(self.contents).count != self.contents.count {
                throw Error.DEV(detail: "remove failed to maintain uniqueness")
            }
            
            return removedElement.audioTrackID
        }
        
        func move(fromOffsets source: IndexSet, toOffset destination: Int) async throws {
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
            
            if Set(self.contents).count != self.contents.count {
                throw Error.DEV(detail: "move failed to maintain uniqueness")
            }
            if recounter != self.audioTrackCounter {
                throw Error.DEV(detail: "move unstabilized counter")
            }
        }
        
        func toBlob() async -> Musubi.Model.Blob {
            return self.contents
                .map({ element in element.audioTrackID })
                .joined(separator: ",")
        }
        
        func toBlobData() async -> Data {
            return Data(await self.toBlob().utf8)
        }
        
        enum Error: LocalizedError {
            case misc(detail: String)
            case DEV(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .misc(detail): "(misc) \(detail)"
                    case let .DEV(detail): "(DEV) \(detail)"
                }
                return "[Musubi::ViewModel::AudioTrackList] \(description)"
            }
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
