// MusubiRepository.swift

import Foundation

// Storage hierarchy:
//      appDir/userID/repoID/
//          objects/
//          (refs/remotes/)origin
//          HEAD
//          index

extension Musubi {
    struct RepositoryHandle: Codable {
        let userID: Spotify.ID
        let playlistID: Spotify.ID
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
        
        init?(handle: RepositoryHandle, userManager: Musubi.UserManager) async {
            self.handle = handle
            
            self.STAGING_AREA_FILE = Musubi.Storage.LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: self.handle)
            self.HEAD_FILE = Musubi.Storage.LocalFS.CLONE_HEAD_FILE(repositoryHandle: self.handle)
            self.FORK_PARENT_FILE = Musubi.Storage.LocalFS.CLONE_FORK_PARENT_FILE(repositoryHandle: self.handle)
            
            do {
                self.stagedAudioTrackList = try await Musubi.ViewModel.AudioTrackList.from(
                    blob: String(contentsOf: STAGING_AREA_FILE, encoding: .utf8),
                    userManager: userManager
                )
                self.headCommitID = try String(contentsOf: HEAD_FILE, encoding: .utf8)
                self.forkParent = try JSONDecoder().decode(RepositoryHandle.self, from: Data(contentsOf: FORK_PARENT_FILE))
            } catch {
                print("[Musubi::RepositoryClone] failed to init for (\(handle.userID), \(handle.playlistID)")
                return nil
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
