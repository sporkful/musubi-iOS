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
    // Note Hashable conformance here is only for SwiftUI List materialization.
    struct RepositoryHandle: Codable, Hashable {
        let userID: Spotify.ID
        let playlistID: Spotify.ID
    }
    
    struct RepositoryExternalMetadata: Codable, Hashable {
        var name: String
        var description: String
        var coverImageURLString: String?
        
        static func fromSpotify(handle: RepositoryHandle) async throws -> Self {
            let metadata = try await SpotifyRequests.Read.playlistMetadata(playlistID: handle.playlistID)
            return Self(
                name: metadata.name,
                description: metadata.descriptionTextFromHTML,
                coverImageURLString: metadata.images?.first?.url
            )
        }
    }
    
    struct RepositoryReference: Codable, Hashable {
        let handle: RepositoryHandle
        var externalMetadata: RepositoryExternalMetadata
    }

    @Observable
    @MainActor
    class RepositoryClone {
        let handle: RepositoryHandle
        
        let stagedAudioTrackList: Musubi.ViewModel.AudioTrackList
        
        var headCommitID: String
        let forkParent: RepositoryHandle?
        
        private let STAGING_AREA_FILE: URL
        private let HEAD_FILE: URL
        private let FORK_PARENT_FILE: URL
        
        // TODO: better way to do this?
        var stagingAreaHydrationError = false // use to trigger alerts on ClonePage view
        
        // TODO: enforce that only MusubiUser can call this constructor
        init(handle: RepositoryHandle) throws {
            self.handle = handle
            
            self.STAGING_AREA_FILE = Musubi.Storage.LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: self.handle)
            self.HEAD_FILE = Musubi.Storage.LocalFS.CLONE_HEAD_FILE(repositoryHandle: self.handle)
            self.FORK_PARENT_FILE = Musubi.Storage.LocalFS.CLONE_FORK_PARENT_FILE(repositoryHandle: self.handle)
            
            self.stagedAudioTrackList = try Musubi.ViewModel.AudioTrackList(audioTracks: [])
            self.headCommitID = try String(contentsOf: HEAD_FILE, encoding: .utf8)
            self.forkParent = try? JSONDecoder().decode(RepositoryHandle.self, from: Data(contentsOf: FORK_PARENT_FILE))
            
            let blob = try String(contentsOf: STAGING_AREA_FILE, encoding: .utf8)
            
            // hydrate stagedAudioTrackList asynchronously
            Task { @MainActor in
                do {
                    for try await audioTrackSublist in SpotifyRequests.Read.audioTracks(audioTrackIDs: blob) {
                        try await self.stagedAudioTrackList.append(audioTracks: audioTrackSublist)
                    }
                } catch {
                    print("[Musubi::RepositoryClone] failed to hydrate stagedAudioTrackList")
                    print(error.localizedDescription)
                    stagingAreaHydrationError = true
                }
            }
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
            
            let proposedCommitBlob = await self.stagedAudioTrackList.toBlob()
            
            let cloudResponse: Musubi.Cloud.Response.Commit = try await Musubi.Cloud.make(
                request: Musubi.Cloud.Request.Commit(
                    playlistID: self.handle.playlistID,
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
