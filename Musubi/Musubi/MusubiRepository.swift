// MusubiRepository.swift

import Foundation

// Storage hierarchy:
//      appDir/userID/repoID/
//          objects/
//          refs/remotes/
//          HEAD
//          index

extension Musubi {
    @Observable
    class RepositoryHandle {
        let userID: Spotify.Model.ID
        let playlistID: Spotify.Model.ID
        
        init(userID: Spotify.Model.ID, playlistID: Spotify.Model.ID) {
            self.userID = userID
            self.playlistID = playlistID
        }
    }
}
