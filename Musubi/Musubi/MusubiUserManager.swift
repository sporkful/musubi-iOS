// MusubiUserManager.swift

import Foundation

extension Musubi {
    @Observable
    class UserManager {
        var loggedInUser: Spotify.Model.LoggedInUser?
        
        @MainActor
        func logOut() {
            Spotify.Auth.clearOAuthCache()
            self.loggedInUser = nil
        }
    }
}
