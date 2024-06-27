// MusubiUser.swift

import Foundation

extension Musubi {
    @Observable
    @MainActor
    class User: Identifiable {
        let spotifyInfo: Spotify.LoggedInUser
        nonisolated var id: Spotify.ID { spotifyInfo.id }
        
        private(set) var localClonesIndex: [Musubi.RepositoryReference]
        private typealias LocalClonesIndexStorageFormat = [Musubi.RepositoryHandle]
        private let LOCAL_CLONES_INDEX_FILE: URL
        
        private(set) var openedLocalClone: Musubi.RepositoryClone?
        
        init(spotifyInfo: Spotify.LoggedInUser) throws {
            self.spotifyInfo = spotifyInfo
            self.localClonesIndex = []
            self.openedLocalClone = nil
            
            self.LOCAL_CLONES_INDEX_FILE = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: spotifyInfo.id)
            
            if Musubi.Storage.LocalFS.doesFileExist(at: self.LOCAL_CLONES_INDEX_FILE) {
                let handles: LocalClonesIndexStorageFormat = try JSONDecoder().decode(
                    LocalClonesIndexStorageFormat.self,
                    from: Data(contentsOf: self.LOCAL_CLONES_INDEX_FILE)
                )
                self.localClonesIndex = handles.map { handle in
                    Musubi.RepositoryReference(handle: handle)
                }
            } else {
                try Musubi.Storage.LocalFS.createNewDir(
                    at: Musubi.Storage.LocalFS.USER_CLONES_DIR(userID: self.id),
                    withIntermediateDirectories: true
                )
                let emptyHandles: LocalClonesIndexStorageFormat = []
                try JSONEncoder().encode(emptyHandles).write(to: self.LOCAL_CLONES_INDEX_FILE, options: .atomic)
            }
            
            // TODO: start playback polling if this is a premium user (here or when HomeView appears?)
        }
        
        private nonisolated func saveClonesIndex() async throws {
            let handles: LocalClonesIndexStorageFormat = await self.localClonesIndex.map { $0.handle }
            try JSONEncoder().encode(handles).write(to: self.LOCAL_CLONES_INDEX_FILE, options: .atomic)
        }
        
        // TODO: do we need to make this async / run on MainActor only? if so how?
        // Called from inside a navigationDestination callback (LocalClonesTabRoot)
        func openLocalClone(repositoryReference referenceToOpen: RepositoryReference) -> RepositoryClone? {
            if referenceToOpen == self.openedLocalClone?.repositoryReference {
                return self.openedLocalClone
            }
            
            if self.localClonesIndex.contains(referenceToOpen) {
                self.openedLocalClone = try? Musubi.RepositoryClone(repositoryReference: referenceToOpen)
            } else {
                self.openedLocalClone = nil
            }
            return self.openedLocalClone
        }
        
        // TODO: change from handles to references
        // TODO: check that repositoryHandles is a subset of those in self.localClonesIndex?
        // TODO: better error handling (e.g. rollback for atomicity)
        func addToLocalClones(newAudioTracks: [Spotify.AudioTrack], destinationHandles: Set<RepositoryHandle>) async throws {
            if newAudioTracks.isEmpty {
                return
            }
            
            if let openedLocalClone = self.openedLocalClone,
               destinationHandles.contains(openedLocalClone.repositoryReference.handle)
            {
                try await openedLocalClone.stagedAudioTrackListAppend(audioTracks: newAudioTracks)
            }
            
            let blobifiedNewAudioTrackIDs = newAudioTracks
                .map({ audioTrack in audioTrack.id })
                .joined(separator: ",")
            
            for handle in destinationHandles {
                if handle != self.openedLocalClone?.repositoryReference.handle {
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
        func initOrClone(repositoryHandle: Musubi.RepositoryHandle) async throws -> Musubi.RepositoryReference {
            if localClonesIndex.contains(where: { $0.handle == repositoryHandle }) {
                throw Musubi.Repository.Error.cloning(detail: "called initOrClone on already cloned repo")
            }
            if repositoryHandle.userID != self.id {
                throw Musubi.Repository.Error.cloning(detail: "called initOrClone on unowned playlist")
            }
            
            let cloudResponse: Musubi.Cloud.Response.Clone = try await Musubi.Cloud.make(
                request: Musubi.Cloud.Request.InitOrClone(
                    playlistID: repositoryHandle.playlistID
                )
            )
            
            try saveClone(repositoryHandle: repositoryHandle, cloudResponse: cloudResponse)
            
            let newRepositoryReference = Musubi.RepositoryReference(handle: repositoryHandle)
            self.localClonesIndex.append(newRepositoryReference)
            // TODO: better error handling here?
            try? await saveClonesIndex()
            
            return newRepositoryReference
        }
        
        // TODO: impl
//        func forkOrClone(ownerID: Spotify.ID, playlistID: Spotify.ID, userManager: Musubi.UserManager) async throws {
//
//        }
        
        // TODO: integrate Musubi.Storage.USER_STAGED_AUDIO_TRACK_INDEX_FILE
        private func saveClone(
            repositoryHandle: Musubi.RepositoryHandle,
            cloudResponse: Musubi.Cloud.Response.Clone
        ) throws {
            typealias LocalFS = Musubi.Storage.LocalFS
            
            guard let headCommit = cloudResponse.commits[cloudResponse.headCommitID],
                  let headBlob = cloudResponse.blobs[headCommit.blobID]
            else {
                throw Musubi.Repository.Error.cloning(detail: "clone response does not have valid head blob")
            }
            
            let cloneDir = LocalFS.CLONE_DIR(repositoryHandle: repositoryHandle)
            if LocalFS.doesDirExist(at: cloneDir) {
                throw Musubi.Repository.Error.cloning(detail: "tried to clone repo that was already cloned")
            }
            try LocalFS.createNewDir(at: cloneDir, withIntermediateDirectories: true)
            
            for (blobID, blob) in cloudResponse.blobs {
                try LocalFS.save(blob: blob, blobID: blobID)
            }
            for (commitID, commit) in cloudResponse.commits {
                try LocalFS.save(commit: commit, commitID: commitID)
            }
            
            try Data(cloudResponse.headCommitID.utf8).write(
                to: LocalFS.CLONE_HEAD_FILE(repositoryHandle: repositoryHandle),
                options: .atomic
            )
            try Data(headBlob.utf8).write(
                to: LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: repositoryHandle),
                options: .atomic
            )
            if let forkParent = cloudResponse.forkParent {
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
  
        // TODO: impl
//        func deleteClone(repositoryHandle: Musubi.RepositoryHandle) {
//
//        }
    }
}
