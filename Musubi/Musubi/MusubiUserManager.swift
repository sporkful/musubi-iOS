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
        private(set) var repositories: [Musubi.Model.RepositoryHandle]
        
        var id: Spotify.Model.ID { spotifyInfo.id }
        
        init(spotifyInfo: Spotify.Model.LoggedInUser) {
            self.spotifyInfo = spotifyInfo
            // TODO: load repos from disk / create if don't exist
            // TODO: create Musubi cloud account for this Spotify user if doesn't exist
            // TODO: start playback controller if this is a premium user
            self.repositories = []
        }
    }
}
