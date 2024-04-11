// MusubiRepository.swift

import Foundation

// Storage hierarchy:
//      appDir/userID/repoID/
//          objects/
//          (refs/remotes/)origin
//          HEAD
//          index

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
        
        init(name: String, description: String, coverImageURLString: String? = nil) {
            self.name = name
            self.description = description
            self.coverImageURLString = coverImageURLString
        }
        
        init(spotifyPlaylistMetadata: Spotify.Playlist) {
            self.name = spotifyPlaylistMetadata.name
            self.description = spotifyPlaylistMetadata.description
            self.coverImageURLString = spotifyPlaylistMetadata.images?.first?.url
        }
    }
    
    struct RepositoryReference: Codable, Hashable {
        let handle: RepositoryHandle
        var externalMetadata: RepositoryExternalMetadata
        
        init(handle: RepositoryHandle, externalMetadata: RepositoryExternalMetadata) {
            self.handle = handle
            self.externalMetadata = externalMetadata
        }
        
        // Avoids triggering unnecessary SwiftUI updates.
        mutating func refreshExternalMetadata(userManager: Musubi.UserManager) async throws {
            let newMetadata = RepositoryExternalMetadata(
                spotifyPlaylistMetadata: try await SpotifyRequests.Read.playlist(
                    playlistID: handle.playlistID,
                    userManager: userManager
                )
            )
            if newMetadata != self.externalMetadata {
                self.externalMetadata = newMetadata
            }
        }
    }

    @Observable
    class RepositoryClone {
        let handle: RepositoryHandle
        
        var stagedAudioTrackList: Musubi.ViewModel.AudioTrackList
        
        var headCommitID: String
        let forkParent: RepositoryHandle?
        
        private let STAGING_AREA_FILE: URL
        private let HEAD_FILE: URL
        private let FORK_PARENT_FILE: URL
        
        // TODO: better way to do this?
        var stagingAreaHydrationError = false // use to trigger alerts on ClonePage view
        
        init(handle: RepositoryHandle, userManager: Musubi.UserManager) throws {
            self.handle = handle
            
            self.STAGING_AREA_FILE = Musubi.Storage.LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: self.handle)
            self.HEAD_FILE = Musubi.Storage.LocalFS.CLONE_HEAD_FILE(repositoryHandle: self.handle)
            self.FORK_PARENT_FILE = Musubi.Storage.LocalFS.CLONE_FORK_PARENT_FILE(repositoryHandle: self.handle)
            
            self.stagedAudioTrackList = []
            self.headCommitID = try String(contentsOf: HEAD_FILE, encoding: .utf8)
            self.forkParent = try? JSONDecoder().decode(RepositoryHandle.self, from: Data(contentsOf: FORK_PARENT_FILE))
            
            Task {
                do {
                    self.stagedAudioTrackList = try await Musubi.ViewModel.AudioTrackList.from(
                        blob: String(contentsOf: STAGING_AREA_FILE, encoding: .utf8),
                        userManager: userManager
                    )
                } catch {
                    print("[Musubi::RepositoryClone] failed to hydrate stagedAudioTrackList")
                    print(error)
                    stagingAreaHydrationError = true
                }
            }
        }
        
        func saveStagingArea() throws {
            try Data(Musubi.Model.Blob.from(audioTrackList: self.stagedAudioTrackList).utf8)
                .write(to: STAGING_AREA_FILE, options: .atomic)
        }
        
        func saveHead() throws {
            try Data(self.headCommitID.utf8)
                .write(to: HEAD_FILE, options: .atomic)
        }
        
        // TODO: impl
//        func push(userManager: Musubi.UserManager) async throws {
//            let requestBody = Push_RequestBody(
//            )
//            var request = try MusubiCloudRequests.createRequest(
//                command: .PUSH,
//                bodyData: try Musubi.jsonEncoder().encode(requestBody)
//            )
//            let responseData = try await userManager.makeAuthdMusubiCloudRequest(request: &request)
//            let response = try Musubi.jsonDecoder().decode(Push_Response.self, from: responseData)
//        }
        
        private struct Push_RequestBody: Encodable {
            let playlistID: String
            let latestSyncCommitID: String
            let proposedCommitInfo: ProposedCommitInfo
            
            struct ProposedCommitInfo: Encodable {
                let blob: Musubi.Model.Blob
                let parentCommitIDs: [String]
                let message: String
            }
        }
        
        private enum Push_Response: Decodable {
            case success
            case remoteUpdates(
                commits: [String: Musubi.Model.Commit],
                blobs: [String: Musubi.Model.Blob]
            )
            case spotifyUpdates(blob: Musubi.Model.Blob)
        }
    }
}
