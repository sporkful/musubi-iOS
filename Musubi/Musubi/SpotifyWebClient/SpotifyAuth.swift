// SpotifyAuth.swift

import Foundation

// MARK: configuration
extension Spotify.Constants {
    static let AUTH_REDIRECT_URI = "https://musubi-iOS.com"
    static let TOKEN_EXPIRATION_BUFFER: TimeInterval = 300
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/scopes
    static let ACCESS_SCOPES = [
//        "ugc-image-upload",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-private",
        "playlist-modify-public",
//        "user-follow-modify",
        "user-follow-read",
        "user-read-playback-position",
        "user-top-read",
        "user-read-recently-played",
//        "user-library-modify",
        "user-library-read",
//        "user-read-email",
//        "user-read-private",
    ]
}

// MARK: convenience
extension Spotify.Constants {
    static var ACCESS_SCOPES_STR: String {
        ACCESS_SCOPES.joined(separator: "%20")
    }
    static var AUTH_PAGE_URL: URL {
        URL(
            string: """
               https://accounts.spotify.com/authorize\
               ?response_type=code\
               &client_id=\(API_CLIENT_ID)\
               &scope=\(ACCESS_SCOPES_STR)\
               &redirect_uri=\(AUTH_REDIRECT_URI)\
               &show_dialog=TRUE
               """
        )!
    }
    static var TOKEN_REQUEST_URL: URL {
        URL(string: "https://accounts.spotify.com/api/token")!
    }
}
