// MusubiRepository.swift

import Foundation

// Storage hierarchy:
//      appDir/userID/repoID/
//          objects/
//          (refs/remotes/)origin
//          HEAD
//          index

extension Musubi {
    struct RepositoryHandle {
        let userID: Spotify.ID
        let playlistID: Spotify.ID
    }
    
    @Observable
    class Repository {
        let handle: RepositoryHandle
        
        var stagedAudioTrackList: Musubi.ViewModel.AudioTrackList
        
        init(handle: RepositoryHandle) {
            self.handle = handle
            
            // TODO: load
            self.stagedAudioTrackList = []
        }
        
        // TODO: impl
//        func push(userManager: Musubi.UserManager) async throws {
//            let requestBody = Push_RequestBody(
//                playlistID: <#T##String#>,
//                proposedCommitHash: <#T##String#>,
//                proposedCommit: <#T##Musubi.Model.Commit#>,
//                latestSyncCommitHash: <#T##String#>
//            )
//            var request = try MusubiCloudRequests.createRequest(
//                command: .PUSH,
//                bodyData: try Musubi.jsonEncoder().encode(requestBody)
//            )
//            let responseData = try await userManager.makeAuthdMusubiCloudRequest(request: &request)
//            let response = try Musubi.jsonDecoder().decode(Push_Response.self, from: responseData)
//        }
        
        private struct Push_RequestBody: Codable {
            let playlistID: String
            let latestSyncCommitHash: Musubi.Model.HashPointer
            let proposedCommitArgs: ProposedCommitArgs
            
            struct ProposedCommitArgs: Codable {
                let blob: Musubi.Model.Blob
                let parentCommits: [Musubi.Model.HashPointer]
                let message: String
            }
        }
        
        private enum Push_Response: Codable {
            case success
            case remoteUpdates(
                commits: [Musubi.Model.HashPointer: Musubi.Model.Commit],
                blobs: [Musubi.Model.HashPointer: Musubi.Model.Blob]
            )
            case spotifyUpdates(blob: Musubi.Model.Blob)
        }
    }
}
