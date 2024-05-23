// MusubiRepository.swift

import Foundation

// namespaces
extension Musubi {
    struct Repository {
        private init() {}
        
        enum Error: LocalizedError {
            case cloning(detail: String)
            case misc(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .cloning(detail): "(initial cloning - check Musubi::UserManager) \(detail)"
                    case let .misc(detail): "\(detail)"
                }
                return "[Musubi::Repository] \(description)"
            }
        }
    }
}

extension Musubi {
    struct RepositoryHandle: Codable, Identifiable, Hashable {
        let userID: Spotify.ID
        let playlistID: Spotify.ID
        
        var id: String { "\(userID):\(playlistID)" }
    }
    
    // Keeping `RepositoryReference`s as "sink"s in the ARC graph generally avoids strong reference
    // cycles. E.g. an opened `RepositoryClone` and its staged `ViewModel.AudioTrackList` are safe
    // to simultaneously refer to the same RepositoryReference.
    
    @Observable
    @MainActor
    class RepositoryReference: Identifiable, Hashable {
        nonisolated let handle: RepositoryHandle
        
        private(set) var externalMetadata: Spotify.PlaylistMetadata?
        
        private var refreshTimer: Timer?
        
        nonisolated var id: String { handle.id }
        
        // TODO: enforce that only MusubiUser can call this constructor
        init(handle: RepositoryHandle) {
            self.handle = handle
            
            Task {
                await startPeriodicRefresh()
            }
        }
        
        private func refresh() async throws {
            let newMetadata = try await SpotifyRequests.Read.playlistMetadata(playlistID: self.handle.playlistID)
            
            // Avoid triggering unnecessary SwiftUI updates.
            if newMetadata != self.externalMetadata {
                self.externalMetadata = newMetadata
            }
        }
        
        private func startPeriodicRefresh() async {
            if self.refreshTimer == nil {
                self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
                    [weak self] (_) in
                    Task { [weak self] in
                        try await self?.refresh()
                    }
                }
                self.refreshTimer?.fire()
            }
        }
        
        func pausePeriodicRefresh(forTimeInSeconds: TimeInterval) async {
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
            
            Task {
                try await Task.sleep(nanoseconds: UInt64(forTimeInSeconds * 1_000_000_000))
                await startPeriodicRefresh()
            }
        }
        
        nonisolated static func == (lhs: Musubi.RepositoryReference, rhs: Musubi.RepositoryReference) -> Bool {
            lhs.handle == rhs.handle
        }
        
        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(handle)
        }
    }
    
    struct RepositoryCommit: Identifiable {
        let repositoryReference: RepositoryReference
        let commitID: String
        let commit: Musubi.Model.Commit
        
        init(repositoryReference: RepositoryReference, commitID: String) throws {
            self.repositoryReference = repositoryReference
            self.commitID = commitID
            self.commit = try Musubi.Storage.LocalFS.loadCommit(commitID: commitID)
        }
        
        var id: String { "\(self.repositoryReference.id):\(self.commitID)" }
    }

    // TODO: take out stagedAudioTrackList and merge this with RepositoryReference (and just call it Repository?)
    @Observable
    @MainActor
    class RepositoryClone {
        let repositoryReference: RepositoryReference
        
        let stagedAudioTrackList: Musubi.ViewModel.AudioTrackList
        
        var headCommitID: String
        let forkParent: RepositoryHandle?
        
        private let STAGING_AREA_FILE: URL
        private let HEAD_FILE: URL
        private let FORK_PARENT_FILE: URL
        
        // TODO: enforce that only MusubiUser can call this constructor
        init(repositoryReference: RepositoryReference) throws {
            self.repositoryReference = repositoryReference
            
            self.STAGING_AREA_FILE = Musubi.Storage.LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: repositoryReference.handle)
            self.HEAD_FILE = Musubi.Storage.LocalFS.CLONE_HEAD_FILE(repositoryHandle: repositoryReference.handle)
            self.FORK_PARENT_FILE = Musubi.Storage.LocalFS.CLONE_FORK_PARENT_FILE(repositoryHandle: repositoryReference.handle)
            
            self.stagedAudioTrackList = Musubi.ViewModel.AudioTrackList(repositoryReference: self.repositoryReference)
            self.headCommitID = try String(contentsOf: HEAD_FILE, encoding: .utf8)
            self.forkParent = try? JSONDecoder().decode(RepositoryHandle.self, from: Data(contentsOf: FORK_PARENT_FILE))
        }
        
        // TODO: review concurrency correctness, keeping actor re-entrancy in mind
        // TODO: integrate Musubi.Storage.USER_STAGED_AUDIO_TRACK_INDEX_FILE
        func stagedAudioTrackListRemove(atOffsets: IndexSet) async throws {
            try await self.stagedAudioTrackList.remove(atOffsets: atOffsets)
            try! await saveStagingArea() // intentional fail-fast
        }
        
        func stagedAudioTracklistMove(fromOffsets: IndexSet, toOffset: Int) async throws {
            try await self.stagedAudioTrackList.move(fromOffsets: fromOffsets, toOffset: toOffset)
            try! await saveStagingArea() // intentional fail-fast
        }
        
        // TODO: fix bug where this (using .count) doesn't take into account earlier removals
        func stagedAudioTrackListAppend(audioTracks: [Spotify.AudioTrack]) async throws {
            try await self.stagedAudioTrackList.append(audioTracks: audioTracks)
            try! await saveStagingArea() // intentional fail-fast
        }

        func saveStagingArea() async throws {
            try await self.stagedAudioTrackList.toBlobData()
                .write(to: STAGING_AREA_FILE, options: .atomic)
        }
        
        func saveHeadPointer() throws {
            try Data(self.headCommitID.utf8)
                .write(to: HEAD_FILE, options: .atomic)
        }
        
        func makeCommit(message: String) async throws {
            guard let currentUser = Musubi.UserManager.shared.currentUser else {
                throw Musubi.Cloud.Error.request(detail: "tried to commitAndPush without active user")
            }
            
            let proposedCommitBlob = try await self.stagedAudioTrackList.toBlob()
            
            let cloudResponse: Musubi.Cloud.Response.Commit = try await Musubi.Cloud.make(
                request: Musubi.Cloud.Request.Commit(
                    playlistID: self.repositoryReference.handle.playlistID,
                    latestSyncCommitID: self.headCommitID,
                    proposedCommit: Musubi.Model.Commit(
                        authorID: currentUser.spotifyInfo.id,
                        date: Date.now,
                        message: message,
                        parentCommitIDs: [self.headCommitID],
                        blobID: proposedCommitBlob.blobID
                    ),
                    proposedCommitBlob: proposedCommitBlob
                )
            )
            
            switch cloudResponse {
            case .success:
                // TODO: diff and save to Spotify
                break
            case let .remoteUpdates(commits, blobs):
                // TODO: cache commits/blobs and update new member var holding head blob of remote
                break
            case let .spotifyUpdates(blob):
                // TODO: update new member var holding head blob of remote
                break
            }
        }
    }
}
