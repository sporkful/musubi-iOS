// MusubiRepository.swift

import Foundation

// Storage hierarchy:
//      appDir/userID/repoID/
//          objects/
//          refs/remotes/
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
        
        func commit() {
            
        }
    }
}
