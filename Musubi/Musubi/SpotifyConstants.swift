// SpotifyConstants.swift

import Foundation

// namespaces
struct SpotifyConstants {
    private init() {}
}

extension SpotifyConstants {
    static let OAUTH_DUMMY_REDIRECT_URI = "https://github.com/musubi-app/musubi-iOS"
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/scopes
    /// As a rule of thumb, Musubi only gives itself write access to things under its version control.
    static var ACCESS_SCOPES_STR: String { ACCESS_SCOPES.joined(separator: " ") }
    static let ACCESS_SCOPES = [
        "ugc-image-upload",
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
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/api-calls
    static let HTTP_SUCCESS_CODES = Set([200, 201, 202, 204])
}
