// SpotifyAuth.swift

import Foundation

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

extension Spotify {
    private static func getToken(queryItems: [URLQueryItem]) async throws {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded ", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = queryItems
        request.httpBody = components.query?.data(using: .utf8)
        
        // TODO: finish
    }
    
}
