// MusubiUserManager.swift

import Foundation

extension Musubi {
    @Observable
    class UserManager {
        var loggedInUser: Spotify.LoggedInUser?
        
        @MainActor
        func logOut() {
            Spotify.clearOAuthCache()
            self.loggedInUser = nil
        }
    }
}
