// MusubiUser.swift

import Foundation

extension Musubi {
    @Observable
    @MainActor
    class User: Identifiable {
        let spotifyInfo: Spotify.LoggedInUser
        nonisolated var id: Spotify.ID { spotifyInfo.id }
        
        typealias LocalClonesIndex = [Musubi.RepositoryReference]
        var localClonesIndex: LocalClonesIndex
        
        var openedLocalClone: Musubi.RepositoryClone?
        
        private var refreshExternalMetadataTimer: Timer?
        
        init?(spotifyInfo: Spotify.LoggedInUser) {
            self.spotifyInfo = spotifyInfo
            self.localClonesIndex = []
            self.openedLocalClone = nil
            
            do {
                let userClonesDir = Musubi.Storage.LocalFS.USER_CLONES_DIR(userID: self.id)
                let userClonesIndexFile = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: self.id)
                
                if Musubi.Storage.LocalFS.doesFileExist(at: userClonesIndexFile) {
                    self.localClonesIndex = try JSONDecoder().decode(
                        LocalClonesIndex.self,
                        from: Data(contentsOf: userClonesIndexFile)
                    )
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
            
            Task {
                await startPeriodicRefreshExternalMetadata()
            }
            
            // TODO: start playback polling if this is a premium user (here or when HomeView appears?)
        }
        
        private func startPeriodicRefreshExternalMetadata() async {
            self.refreshExternalMetadataTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
                [weak self] (_) in
                Task { [weak self] in
                    await self?.refreshClonesExternalMetadata()
                }
            }
            self.refreshExternalMetadataTimer?.fire()
        }
        
        func pausePeriodicRefreshExternalMetadata(forTimeInSeconds: TimeInterval) async {
            self.refreshExternalMetadataTimer?.invalidate()
            self.refreshExternalMetadataTimer = nil
            
            Task {
                try await Task.sleep(nanoseconds: UInt64(forTimeInSeconds * 1_000_000_000))
                await startPeriodicRefreshExternalMetadata()
            }
        }
        
        // TODO: better error handling / retries?
        private func refreshClonesExternalMetadata() async {
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
                let handle = self.localClonesIndex[i].handle
                guard let newMetadata = try? await Musubi.RepositoryExternalMetadata.fromSpotify(handle: handle) else {
                    // The erroring of the external request itself implies nothing about the index.
                    continue
                }
                
                guard self.localClonesIndex.indices.contains(i),
                      self.localClonesIndex[i].handle == handle
                else {
                    break
                }
                // Avoid triggering unnecessary SwiftUI updates.
                if newMetadata != self.localClonesIndex[i].externalMetadata {
                    self.localClonesIndex[i].externalMetadata = newMetadata
                }
            }
            Task {
                try? await saveClonesIndex()
            }
        }
        
        private nonisolated func saveClonesIndex() async throws {
            let userClonesIndexFile = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: self.id)
            try JSONEncoder().encode(await self.localClonesIndex).write(to: userClonesIndexFile, options: .atomic)
        }
        
        // TODO: do we need to make this async to run on MainActor only?
        func openLocalClone(repositoryHandle: RepositoryHandle) -> RepositoryClone? {
            if self.openedLocalClone?.handle != repositoryHandle {
                self.openedLocalClone = try? Musubi.RepositoryClone(handle: repositoryHandle)
            }
            return self.openedLocalClone
        }
        
        // TODO: reason more carefully about concurrency correctness, especially wrt openedLocalClone
        // For now, just assumes the caller disables all UI until function finishes executing.
        func addToLocalClones(newAudioTrackIDs: [Spotify.ID], destinationHandles: Set<RepositoryHandle>) async throws {
            // TODO: check that repositoryHandles is a subset of those in self.localClonesIndex?
            
            let blobifiedNewAudioTrackIDs = newAudioTrackIDs.joined(separator: ",")
            
            var newAudioTracks: [Spotify.AudioTrack] = []
            if let openedLocalClone = self.openedLocalClone,
               destinationHandles.contains(openedLocalClone.handle)
            {
                // TODO: deduplicate logic with MusubiRepository constructor
                var numCommasSeen = 0
                var currentRangeStartIndex = blobifiedNewAudioTrackIDs.startIndex
                for index in blobifiedNewAudioTrackIDs.indices {
                    if blobifiedNewAudioTrackIDs[index] == "," {
                        numCommasSeen += 1
                        if numCommasSeen % 50 == 0 {
                            newAudioTracks.append(
                                contentsOf: try await SpotifyRequests.Read.audioTracks(
                                    audioTrackIDs: String(blobifiedNewAudioTrackIDs[currentRangeStartIndex..<index])
                                )
                            )
                            currentRangeStartIndex = blobifiedNewAudioTrackIDs.index(after: index)
                        }
                    }
                }
                if !(blobifiedNewAudioTrackIDs.last == "," && numCommasSeen % 50 == 0) {
                    newAudioTracks.append(
                        contentsOf: try await SpotifyRequests.Read.audioTracks(
                            audioTrackIDs: String(blobifiedNewAudioTrackIDs[currentRangeStartIndex...])
                        )
                    )
                }
                openedLocalClone.stagedAudioTrackList.append(audioTrackList: newAudioTracks)
            }
            
            for handle in destinationHandles {
                if handle != self.openedLocalClone?.handle {
                    let stagingAreaFile = Musubi.Storage.LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: handle)
                    var blob = try String(contentsOf: stagingAreaFile, encoding: .utf8)
                    if !blob.isEmpty {
                        blob.append(",")
                    }
                    blob.append(blobifiedNewAudioTrackIDs)
                    try Data(blob.utf8).write(to: stagingAreaFile, options: .atomic)
                }
            }
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
                bodyData: try MusubiCloudRequests.jsonEncoder().encode(requestBody)
            )
            let responseData = try await Musubi.UserManager.shared.makeAuthdMusubiCloudRequest(request: &request)
            
            try saveClone(
                repositoryHandle: repositoryHandle,
                response: try MusubiCloudRequests.jsonDecoder().decode(Clone_ResponseBody.self, from: responseData)
            )
            
            self.localClonesIndex.append(
                Musubi.RepositoryReference(
                    handle: repositoryHandle,
                    externalMetadata: try await Musubi.RepositoryExternalMetadata.fromSpotify(handle: repositoryHandle)
                )
            )
            // TODO: better error handling here?
            try? await saveClonesIndex()
        }
        
        // TODO: impl
//        func forkOrClone(ownerID: Spotify.ID, playlistID: Spotify.ID, userManager: Musubi.UserManager) async throws {
//
//        }
        
        // TODO: integrate Musubi.Storage.USER_STAGED_AUDIO_TRACK_INDEX_FILE
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
                try Data(blob.utf8).write(
                    to: LocalFS.GLOBAL_OBJECT_FILE(objectID: blobID),
                    options: .atomic
                )
            }
            for (commitID, commit) in response.commits {
                try JSONEncoder().encode(commit).write(
                    to: LocalFS.GLOBAL_OBJECT_FILE(objectID: commitID),
                    options: .atomic
                )
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
