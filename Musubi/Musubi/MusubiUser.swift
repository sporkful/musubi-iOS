// MusubiUser.swift

import Foundation

extension Musubi {
    @Observable
    @MainActor
    class User: Identifiable {
        let spotifyInfo: Spotify.LoggedInUser
        
        typealias LocalClonesIndex = [Musubi.RepositoryReference]
        var localClonesIndex: LocalClonesIndex
        
        nonisolated var id: Spotify.ID { spotifyInfo.id }
        
        init?(spotifyInfo: Spotify.LoggedInUser) {
            self.spotifyInfo = spotifyInfo
            self.localClonesIndex = []
            
            do {
                let userClonesDir = Musubi.Storage.LocalFS.USER_CLONES_DIR(userID: self.id)
                let userClonesIndexFile = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: self.id)
                
                if Musubi.Storage.LocalFS.doesFileExist(at: userClonesIndexFile) {
                    self.localClonesIndex = try JSONDecoder().decode(
                        LocalClonesIndex.self,
                        from: Data(contentsOf: userClonesIndexFile)
                    )
                    Task {
                        await refreshClonesExternalMetadata()
                    }
                } else {
                    try Musubi.Storage.LocalFS.createNewDir(
                        at: userClonesDir,
                        withIntermediateDirectories: true
                    )
                    try JSONEncoder().encode(self.localClonesIndex).write(to: userClonesIndexFile, options: .atomic)
                }
            } catch {
                print("[Musubi::User] failed to init user for \(spotifyInfo.display_name)")
                return nil
            }
            
            // TODO: start playback polling if this is a premium user (here or when HomeView appears?)
        }
        
        // TODO: better error handling / retries
        func refreshClonesExternalMetadata() async {
            // Note that indices into `self.localClonesIndex` are not guaranteed to be stable for
            // the full execution of the for-loop due to the `await`ing of the Spotify request on
            // every iteration. Since this function is meant to be called periodically in the
            // background and we don't need particularly strong consistency guarantees
            // (it deals with Spotify-controlled metadata that we explicitly don't version control),
            // we choose to `break` as soon as we detect that the underlying index has changed from
            // when the function was invoked.
            for i in self.localClonesIndex.indices {
                guard self.localClonesIndex.indices.contains(i) else {
                    break
                }
                let playlistID = self.localClonesIndex[i].handle.playlistID
                guard let playlistMetadata = try? await SpotifyRequests.Read.playlist(playlistID: playlistID) else {
                    // The erroring of the Spotify request itself implies nothing about the index.
                    continue
                }
                guard self.localClonesIndex.indices.contains(i),
                      playlistMetadata.id == self.localClonesIndex[i].handle.playlistID
                else {
                    break
                }
                // Avoid triggering unnecessary SwiftUI updates.
                let newExternalMetadata = Musubi.RepositoryExternalMetadata(
                    spotifyPlaylistMetadata: playlistMetadata
                )
                if newExternalMetadata != self.localClonesIndex[i].externalMetadata {
                    self.localClonesIndex[i].externalMetadata = newExternalMetadata
                }
            }
            Task {
                try? await saveClonesIndex()
            }
        }
        
        nonisolated func saveClonesIndex() async throws {
            let userClonesIndexFile = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: self.id)
            try JSONEncoder().encode(await self.localClonesIndex).write(to: userClonesIndexFile, options: .atomic)
        }
        
        // TODO: clean up reference-spaghetti between User and UserManager?
        func initOrClone(repositoryHandle: Musubi.RepositoryHandle) async throws {
            if localClonesIndex.contains(where: { $0.handle == repositoryHandle }) {
                throw Musubi.RepositoryError.cloning(detail: "called initOrClone on already cloned repo")
            }
            if repositoryHandle.userID != self.id {
                throw Musubi.RepositoryError.cloning(detail: "called initOrClone on unowned playlist")
            }
            
            let requestBody = InitOrClone_RequestBody(playlistID: repositoryHandle.playlistID)
            var request = try MusubiCloudRequests.createRequest(
                command: .INIT_OR_CLONE,
                bodyData: try Musubi.jsonEncoder().encode(requestBody)
            )
            let responseData = try await Musubi.UserManager.shared.makeAuthdMusubiCloudRequest(request: &request)
            
            try saveClone(
                repositoryHandle: repositoryHandle,
                response: try Musubi.jsonDecoder().decode(Clone_ResponseBody.self, from: responseData)
            )
            
            self.localClonesIndex.append(
                Musubi.RepositoryReference(
                    handle: repositoryHandle,
                    externalMetadata: Musubi.RepositoryExternalMetadata(
                        spotifyPlaylistMetadata: try await SpotifyRequests.Read.playlist(playlistID: repositoryHandle.playlistID)
                    )
                )
            )
            // TODO: better error handling here?
            try? await saveClonesIndex()
        }
        
        // TODO: impl
//        func forkOrClone(ownerID: Spotify.ID, playlistID: Spotify.ID, userManager: Musubi.UserManager) async throws {
//
//        }
        
        private func saveClone(repositoryHandle: Musubi.RepositoryHandle, response: Clone_ResponseBody) throws {
            typealias LocalFS = Musubi.Storage.LocalFS
            
            guard let headCommit = response.commits[response.headCommitID],
                  let headBlob = response.blobs[headCommit.blobID]
            else {
                throw Musubi.RepositoryError.cloning(detail: "clone response does not have valid head blob")
            }
            
            let cloneDir = LocalFS.CLONE_DIR(repositoryHandle: repositoryHandle)
            if LocalFS.doesDirExist(at: cloneDir) {
                throw Musubi.RepositoryError.cloning(detail: "tried to clone repo that was already cloned")
            }
            try LocalFS.createNewDir(at: cloneDir, withIntermediateDirectories: true)
            
            for (blobID, blob) in response.blobs {
                try LocalFS.saveGlobalObject(object: blob, objectID: blobID)
            }
            for (commitID, commit) in response.commits {
                try LocalFS.saveGlobalObject(object: commit, objectID: commitID)
            }
            
            try Data(response.headCommitID.utf8).write(
                to: LocalFS.CLONE_HEAD_FILE(repositoryHandle: repositoryHandle),
                options: .atomic
            )
            try Data(headBlob.utf8).write(
                to: LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: repositoryHandle),
                options: .atomic
            )
            if let forkParent = response.forkParent {
                let forkParentHandle = Musubi.RepositoryHandle(
                    userID: forkParent.userID,
                    playlistID: forkParent.playlistID
                )
                try JSONEncoder().encode(forkParentHandle).write(
                    to: LocalFS.CLONE_FORK_PARENT_FILE(repositoryHandle: repositoryHandle),
                    options: .atomic
                )
            }
        }
        
        private struct InitOrClone_RequestBody: Encodable {
            let playlistID: String
        }
        
        private struct Clone_ResponseBody: Decodable {
            let commits: [String: Musubi.Model.Commit]
            let blobs: [String: Musubi.Model.Blob]
            
            let headCommitID: String
            let forkParent: RelatedRepository?
            
            struct RelatedRepository: Decodable {
                let userID: String
                let playlistID: String
                // Note omission of remotely-mutable `LatestSyncCommitID`, which is handled by backend.
            }
        }
  
        // TODO: impl
//        func deleteClone(repositoryHandle: Musubi.RepositoryHandle) {
//
//        }
    }
}
