// SpotifyModel.swift

import Foundation

extension Spotify {
    typealias ID = String
    
    struct AuthResponse: Codable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String
        let token_type: String
    }
}

// namespaces
struct Spotify {
    private init() { }
    
    struct Constants {
        private init() { }
    }
}
