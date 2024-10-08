// MusubiViewModel.swift

import Foundation

// namespaces
extension Musubi {
    struct ViewModel {
        private init() { }
    }
}

// TODO: extract what's necessary for AudioTrackListPage vs PlayerSheet
protocol AudioTrackListContext {
    var id: String { get } // TODO: check that IDs are unique across types
    var uri: String { get }
    var name: String { get }
    var formattedDescription: String? { get }
    var coverImageURLString: String? { get }
    var associatedPeople: [any SpotifyPerson] { get }
    var associatedDate: String? { get }
    var type: String { get }
}

// TODO: make more explicit that this context represents a clone's staging area?
extension Musubi.RepositoryReference: AudioTrackListContext {
    var uri: String { "musubi:repository:\(self.id)" }
    var name: String { self.externalMetadata?.name ?? "(Loading local clone...)" }
    var formattedDescription: String? { self.externalMetadata?.formattedDescription }
    var coverImageURLString: String? { self.externalMetadata?.images?.first?.url }
    var associatedPeople: [any SpotifyPerson] {
        if let currentUserInfo = Musubi.UserManager.shared.currentUser?.spotifyInfo {
            [currentUserInfo]
        } else {
            []
        }
    }
    var associatedDate: String? { nil }  // TODO: latest commit date?
    var type: String { "Musubi Local Clone" }
}

extension Musubi.RepositoryCommit: AudioTrackListContext {
    var uri: String { "musubi:commit:\(self.id)" }
    @MainActor var name: String { "\(self.repositoryReference.name)\n\"\(self.commit.message)\"" }
    var formattedDescription: String? { nil }
    var coverImageURLString: String? { nil }
    var associatedPeople: [any SpotifyPerson] {
        if let currentUserInfo = Musubi.UserManager.shared.currentUser?.spotifyInfo {
            [currentUserInfo]
        } else {
            []
        }
    }
    var associatedDate: String? { self.commit.date.formatted() }
    var type: String { "Musubi Repository Commit" }
}

extension Spotify.AlbumMetadata: AudioTrackListContext {
    var formattedDescription: String? { nil }
    var coverImageURLString: String? { self.images?.first?.url }
    var associatedPeople: [any SpotifyPerson] { self.artists }
    var associatedDate: String? { "Release Date: \(self.release_date)" }
    var type: String {
        if self.album_type.lowercased() != "album" {
            "Spotify Album (\(self.album_type.capitalized))"
        } else {
            "Spotify Album"
        }
    }
}

extension Spotify.PlaylistMetadata: AudioTrackListContext {
    var formattedDescription: String? { self.descriptionTextFromHTML }
    var coverImageURLString: String? { self.images?.first?.url }
    var associatedPeople: [any SpotifyPerson] { [self.owner] }
    var associatedDate: String? { nil }  // TODO: last modified from Spotify API?
    var type: String { "Spotify Playlist" }
}

// TODO: remove this for clarity (held up by SelectAddAudioTracks)
extension Spotify.AudioTrack: AudioTrackListContext {
    var formattedDescription: String? { nil }
    var coverImageURLString: String? { self.images?.first?.url }
    var associatedPeople: [any SpotifyPerson] { self.artists }
    var associatedDate: String? { self.album?.release_date }
    var type: String { "Spotify Track" }
}

extension Musubi.ViewModel {
    // TODO: rethink design - currently `parent` isn't included in `==` of `AudioTrack`s since
    // that breaks assumptions that were made when developing diffing functionality.
    // However, this behavior can be unexpected and undesirable down the road.
    struct AudioTrack: Equatable, Hashable, CustomStringConvertible {
        let audioTrackID: Spotify.ID  // note redundancy with self.audioTrack is for legacy reasons.
        
        weak var parent: AudioTrackList?
        let occurrence: Int  // per-value counter starting at 1
        
        let audioTrack: Spotify.AudioTrack
        
        init(audioTrackID: Spotify.ID, parent: AudioTrackList, occurrence: Int, audioTrack: Spotify.AudioTrack) {
            self.audioTrackID = audioTrackID
            self.parent = parent
            self.occurrence = occurrence
            self.audioTrack = audioTrack
        }
        
        init(audioTrack: Spotify.AudioTrack) {
            self.audioTrackID = audioTrack.id
            self.parent = nil
            self.occurrence = 1
            self.audioTrack = audioTrack
        }
        
        /*
         // TODO: revisit this if memory efficiency needed, e.g. with global shared cache of track data.
         
         // for audio tracks with no parent, e.g. from search
         private var _audioTrack: Spotify.AudioTrack?
         
         var audioTrack: Spotify.AudioTrack? {
         get async {
         if let _audioTrack = _audioTrack {
         return _audioTrack
         } else {
         return await self.parent?.audioTrackData[audioTrackID]
         }
         }
         }
         
         init(audioTrackID: Spotify.ID, occurrence: Int, parent: AudioTrackList) {
         self.audioTrackID = audioTrackID
         self.occurrence = occurrence
         self.parent = parent
         self._audioTrack = nil
         }
         
         init(audioTrack: Spotify.AudioTrack) {
         self.audioTrackID = audioTrack.id
         self.occurrence = 1
         self.parent = nil
         self._audioTrack = audioTrack
         }
         
         */
        
        var description: String { "(\"\(audioTrackID)\", \(occurrence))" }
        
        // TODO: conform AudioTrackList itself to Equatable/Hashable using context id?
        
        static func == (
            lhs: Musubi.ViewModel.AudioTrack,
            rhs: Musubi.ViewModel.AudioTrack
        ) -> Bool {
            return lhs.audioTrackID == rhs.audioTrackID
            && lhs.occurrence == rhs.occurrence
            //                && lhs.parent?.context.id == rhs.parent?.context.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(audioTrackID)
            hasher.combine(occurrence)
            //            hasher.combine(parent?.context.id ?? "")
        }
    }
    
    // TODO: figure out better abstraction/composition that can support private(set) semantics for e.g. remote playlists
    @Observable
    @MainActor
    class AudioTrackList {
        nonisolated let context: any AudioTrackListContext
        
        private(set) var contents: [AudioTrack]
        
        private(set) var audioTrackCounter: [Spotify.ID : Int]
        //        private(set) var audioTrackData: [Spotify.ID : Spotify.AudioTrack]
        
        // temporary placeholder for above - see AudioTrack definition above for origin
        func audioTrackData() async -> [Spotify.ID : Spotify.AudioTrack] {
            Dictionary(
                self.contents.map { ($0.audioTrackID, $0.audioTrack) },
                uniquingKeysWith: { (first, _) in first }
            )
        }
        
        // TODO: check correctness of this, esp wrt deadlocks (current sol is ad-hoc)
        // TODO: automate v for all nonprivate async funcs?
        // Anything that requires the AudioTrackList to be fully hydrated as a precondition can
        // `try await initialHydrationTask.value`.
        // This pattern is memory leak free according to:
        // https://forums.swift.org/t/caveats-of-keeping-task-instance-beyond-its-bodys-execution/62400
        var initialHydrationTask: Task<Void, Error>
        
        // TODO: alerts
        // For tying SwiftUI alerts onto.
        private(set) var initialHydrationError: Error? = nil
        private(set) var initialHydrationCompleted: Bool = false
        
        init(repositoryReference: Musubi.RepositoryReference) {
            self.context = repositoryReference
            self.contents = []
            self.audioTrackCounter = [:]
            self.initialHydrationTask = Task {}
            
            self.initialHydrationTask = Task {
                do {
                    // TODO: how to deal with other "live" AudioTrackLists for the same repositoryReference / staging area?
                    let savedStagingArea = try String(
                        contentsOf: Musubi.Storage.LocalFS.CLONE_STAGING_AREA_FILE(
                            repositoryHandle: repositoryReference.handle
                        ),
                        encoding: .utf8
                    )
                    if savedStagingArea.isEmpty {
                        initialHydrationCompleted = true
                        return
                    }
                    
                    for try await sublist in SpotifyRequests.Read.audioTracks(audioTrackIDs: savedStagingArea) {
                        try await self.initialHydrationAppend(audioTracks: sublist)
                    }
                    initialHydrationCompleted = true
                } catch {
                    print("[Musubi::AudioTrackList] failed to hydrate for local clone")
                    print(error.localizedDescription)
                    self.initialHydrationError = error
                    throw error
                }
            }
        }
        
        init(repositoryCommit: Musubi.RepositoryCommit, knownAudioTrackData: [Spotify.ID : Spotify.AudioTrack]? = nil) {
            self.context = repositoryCommit
            self.contents = []
            self.audioTrackCounter = [:]
            //            self.audioTrackData = knownAudioTrackData ?? [:]
            self.initialHydrationTask = Task {}
            
            self.initialHydrationTask = Task {
                do {
                    var relevantAudioTrackData: [Spotify.ID : Spotify.AudioTrack] = knownAudioTrackData ?? [:]
                    
                    let blob = try Musubi.Storage.LocalFS.loadBlob(blobID: repositoryCommit.commit.blobID)
                    if blob.isEmpty {
                        initialHydrationCompleted = true
                        return
                    }
                    
                    let blobAudioTrackIDList: [Spotify.ID] = blob.components(separatedBy: ",")
                    
                    for try await sublist in SpotifyRequests.Read.audioTracks(
                        audioTrackIDs: Set(blobAudioTrackIDList)
                            .subtracting(relevantAudioTrackData.keys)
                            .joined(separator: ",")
                    ) {
                        sublist.forEach { audioTrack in
                            relevantAudioTrackData[audioTrack.id] = audioTrack
                        }
                    }
                    
                    try await self.initialHydrationAppend(
                        audioTracks: blobAudioTrackIDList.map { id in
                            guard let audioTrack = relevantAudioTrackData[id] else {
                                throw CustomError.DEV(detail: "missing audio track data")
                            }
                            return audioTrack
                        }
                    )
                    initialHydrationCompleted = true
                } catch {
                    print("[Musubi::AudioTrackList] failed to hydrate for repository commit")
                    print(error.localizedDescription)
                    self.initialHydrationError = error
                    throw error
                }
            }
        }
        
        // TODO: handle podcasts and local files
        init(playlistMetadata: Spotify.PlaylistMetadata) {
            self.context = playlistMetadata
            self.contents = []
            self.audioTrackCounter = [:]
            self.initialHydrationTask = Task {}
            
            self.initialHydrationTask = Task {
                do {
                    for try await sublist in SpotifyRequests.Read.playlistTrackListFull(playlistID: playlistMetadata.id) {
                        try await self.initialHydrationAppend(audioTracks: sublist)
                    }
                    initialHydrationCompleted = true
                } catch {
                    print("[Musubi::AudioTrackList] failed to hydrate for Spotify playlist")
                    print(error.localizedDescription)
                    self.initialHydrationError = error
                    throw error
                }
            }
        }
        
        init(albumMetadata: Spotify.AlbumMetadata) {
            self.context = albumMetadata
            self.contents = []
            self.audioTrackCounter = [:]
            self.initialHydrationTask = Task {}
            
            self.initialHydrationTask = Task {
                do {
                    for try await sublist in SpotifyRequests.Read.albumTrackListFull(albumID: albumMetadata.id) {
                        try await self.initialHydrationAppend(
                            audioTracks: sublist.map { audioTrack in
                                Spotify.AudioTrack(audioTrack: audioTrack, withAlbumMetadata: albumMetadata)
                            }
                        )
                    }
                    initialHydrationCompleted = true
                } catch {
                    print("[Musubi::AudioTrackList] failed to hydrate for Spotify album")
                    print(error.localizedDescription)
                    self.initialHydrationError = error
                    throw error
                }
            }
        }
        
        init(audioTrack: Spotify.AudioTrack) {
            self.context = audioTrack
            self.contents = []
            self.audioTrackCounter = [:]
            self.initialHydrationTask = Task {}
            
            try! self._append(audioTracks: [audioTrack])
            initialHydrationCompleted = true
        }
        
        private func initialHydrationAppend(audioTracks: [Spotify.AudioTrack]) async throws {
            // MARK: `try await self.initialHydrationTask.value` here would cause deadlock!
            
            try self._append(audioTracks: audioTracks)
        }
        
        func append(audioTracks: [Spotify.AudioTrack]) async throws {
            try await self.initialHydrationTask.value
            
            try self._append(audioTracks: audioTracks)
        }
        
        private func _append(audioTracks: [Spotify.AudioTrack]) throws {
            for audioTrack in audioTracks {
                //                if self.audioTrackData[audioTrack.id] == nil {
                //                    self.audioTrackData[audioTrack.id] = audioTrack
                //                }
                self.audioTrackCounter[audioTrack.id] = (self.audioTrackCounter[audioTrack.id] ?? 0) + 1
                self.contents.append(
                    AudioTrack(
                        audioTrackID: audioTrack.id,
                        parent: self,
                        occurrence: self.audioTrackCounter[audioTrack.id]!,
                        audioTrack: audioTrack
                    )
                )
            }
            
            if Set(self.contents).count != self.contents.count {
                throw CustomError.DEV(detail: "append failed to maintain uniqueness")
            }
        }
        
        func removeAll() async throws {
            try await self.initialHydrationTask.value
            
            self._removeAll()
        }
        
        private func _removeAll() {
            self.contents = []
            self.audioTrackCounter = [:]
        }
        
        func remove(at index: Int) async throws -> Spotify.ID {
            try await self.initialHydrationTask.value
            
            return try self._remove(at: index)
        }
        
        func remove(atOffsets offsets: IndexSet) async throws -> [Spotify.ID] {
            try await self.initialHydrationTask.value
            
            var removedElements: [Spotify.ID] = []
            for offset in offsets.sorted().reversed() {
                removedElements.append(try self._remove(at: offset))
            }
            return removedElements
        }
        
        func _remove(at index: Int) throws -> Spotify.ID {
            let removedElement = self.contents.remove(at: index)
            
            self.audioTrackCounter[removedElement.audioTrackID]! -= 1
            if self.audioTrackCounter[removedElement.audioTrackID] == 0 {
                self.audioTrackCounter[removedElement.audioTrackID] = nil
            }
            
            self.contents.indices.forEach { i in
                if self.contents[i].audioTrackID == removedElement.audioTrackID
                    && self.contents[i].occurrence > removedElement.occurrence
                {
                    self.contents[i] = AudioTrack(
                        audioTrackID: self.contents[i].audioTrackID,
                        parent: self,
                        occurrence: self.contents[i].occurrence - 1,
                        audioTrack: self.contents[i].audioTrack
                    )
                }
            }
            
            if Set(self.contents).count != self.contents.count {
                throw CustomError.DEV(detail: "remove failed to maintain uniqueness")
            }
            
            return removedElement.audioTrackID
        }
        
        func move(fromOffsets source: IndexSet, toOffset destination: Int) async throws {
            try await self.initialHydrationTask.value
            
            self.contents.move(fromOffsets: source, toOffset: destination)
            
            var recounter: [Spotify.ID : Int] = [:]
            for (i, element) in self.contents.enumerated() {
                recounter[element.audioTrackID] = (recounter[element.audioTrackID] ?? 0) + 1
                if element.occurrence != recounter[element.audioTrackID]! {
                    self.contents[i] = AudioTrack(
                        audioTrackID: element.audioTrackID,
                        parent: self,
                        occurrence: recounter[element.audioTrackID]!,
                        audioTrack: element.audioTrack
                    )
                }
            }
            
            if Set(self.contents).count != self.contents.count {
                throw CustomError.DEV(detail: "move failed to maintain uniqueness")
            }
            if recounter != self.audioTrackCounter {
                throw CustomError.DEV(detail: "move unstabilized counter")
            }
        }
        
        // Note no need to use another hydration task since this is fully MainActor-isolated and is
        // not bound by expensive I/O.
        func refreshContentsIfNeeded(newContents: [Spotify.AudioTrack]) async throws {
            try await self.initialHydrationTask.value
            
            if newContents != self.contents.map({ $0.audioTrack }) {
                self._removeAll()
                try self._append(audioTracks: newContents)
            }
        }
        
        func toBlob() async throws -> Musubi.Model.Blob {
            try await self.initialHydrationTask.value
            
            return self.contents
                .map({ element in element.audioTrackID })
                .joined(separator: ",")
        }
        
        func toBlobData() async throws -> Data {
            try await self.initialHydrationTask.value
            
            return Data(try await self.toBlob().utf8)
        }
        
        enum CustomError: LocalizedError {
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
        
        // MARK: - FOR TESTING
        
        private init(audioTracks: [Spotify.AudioTrack]) {
            self.context = Spotify.AlbumMetadata(
                id: "dummyalbum",
                album_type: "",
                images: nil,
                name: "dummyalbum",
                release_date: "",
                artists: []
            )
            self.contents = []
            self.audioTrackCounter = [:]
            self.initialHydrationTask = Task {}
            
            self.initialHydrationTask = Task {
                try await Task.sleep(until: .now + .seconds(1.0), clock: .continuous)
                if audioTracks.count <= 3 {
                    try await self.initialHydrationAppend(audioTracks: audioTracks)
                    return
                }
                try await self.initialHydrationAppend(audioTracks: Array(audioTracks[0..<3]))
                try await Task.sleep(until: .now + .seconds(1.0), clock: .continuous)
                try await self.initialHydrationAppend(audioTracks: Array(audioTracks[3...]))
            }
        }
        
        static func initTestInstance(audioTracks: [Spotify.AudioTrack]) -> Musubi.ViewModel.AudioTrackList {
            return Musubi.ViewModel.AudioTrackList(audioTracks: audioTracks)
        }
    }
}
