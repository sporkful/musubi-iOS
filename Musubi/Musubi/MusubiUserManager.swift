// MusubiUserManager.swift

import Foundation

// UserManager and User are intentionally separated for better organization throughout the app.
// For example, most subviews of HomeView need to be able to refer to the current user but
// don't need / shouldn't have access to login-logout functionality.

extension Musubi {
    @Observable
    class UserManager {
        private(set) var currentUser: Musubi.User? = nil
        
        @MainActor
        func logIn(spotifyInfo: Spotify.Model.LoggedInUser) {
            self.currentUser = User(spotifyInfo: spotifyInfo)
        }
        
        @MainActor
        func logOut() {
            Spotify.Auth.clearOAuthCache()
            self.currentUser = nil
        }
    }
}

extension Musubi {
    @Observable
    class User: Identifiable {
        let spotifyInfo: Spotify.Model.LoggedInUser
        
        private(set) var localClones: [RepositoryHandle]
        
        var id: Spotify.Model.ID { spotifyInfo.id }
        
        private var localBaseDir: URL {
            URL.libraryDirectory
                .appending(path: "MusubiLocal", directoryHint: .isDirectory)
                .appending(path: "Users", directoryHint: .isDirectory)
                .appending(path: self.id, directoryHint: .isDirectory)
                .appending(path: "LocalClones", directoryHint: .isDirectory)
        }
        
        init?(spotifyInfo: Spotify.Model.LoggedInUser) {
            self.spotifyInfo = spotifyInfo
            self.localClones = []
            
            do {
                if Musubi.Storage.LocalFS.doesDirExist(at: self.localBaseDir) {
                    self.localClones = try Musubi.Storage.LocalFS.contentsOf(dirURL: self.localBaseDir)
                        .map { url in url.lastPathComponent }
                        .map { playlistID in
                            Musubi.RepositoryHandle(
                                userID: self.spotifyInfo.id,
                                playlistID: playlistID
                            )
                        }
                } else {
                    try Musubi.Storage.LocalFS.createNewDir(
                        at: self.localBaseDir,
                        withIntermediateDirectories: true
                    )
                }
                
                // TODO: create Musubi cloud account for this Spotify user if doesn't exist
                // TODO: start playback controller if this is a premium user
            } catch {
                print("[Musubi::User] failed to init user for \(spotifyInfo.display_name)")
                return nil
            }
        }
    }
}
