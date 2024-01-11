// SpotifyAuth.swift

import Foundation

extension Spotify.Constants {
    static let AUTH_REDIRECT_URI = "https://musubi-iOS.com"
    static let TOKEN_EXPIRATION_BUFFER: TimeInterval = 300
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/scopes
    private static let ACCESS_SCOPES = [
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
    
    static var ACCESS_SCOPES_STR: String { ACCESS_SCOPES.joined(separator: " ") }
}

extension Spotify {
    static func createAuthRequest(pkceChallenge: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/authorize")!)
        request.httpMethod = "GET"
//        request.setValue("application/x-www-form-urlencoded ", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.API_CLIENT_ID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Constants.AUTH_REDIRECT_URI),
//            URLQueryItem(name: "state", value: ),
            URLQueryItem(name: "scope", value: Constants.ACCESS_SCOPES_STR),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: pkceChallenge),
        ]
        request.httpBody = components.query?.data(using: .utf8)
        
        return request
    }
    
    private static func cacheToken(authResponse: AuthResponse) throws {
        try Musubi.Storage.Keychain.save(
            keyName: .oauthToken,
            value: Data(authResponse.access_token.utf8)
        )
        
        if let refresh_token = authResponse.refresh_token {
            try Musubi.Storage.Keychain.save(
                keyName: .oauthRefreshToken,
                value: Data(refresh_token.utf8)
            )
        }
        
        let newExpirationTime = Date.now
            .addingTimeInterval(TimeInterval(authResponse.expires_in))
            .timeIntervalSince1970
        try Musubi.Storage.Keychain.save(
            keyName: .oauthExpirationDate,
            value: withUnsafeBytes(of: newExpirationTime) { Data($0) }
        )
    }
    
    static func fetchToken(authCode: String, pkceVerifier: String) async throws {
        let response = try await requestToken(
            queryItems: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: authCode),
                URLQueryItem(name: "redirect_uri", value: Constants.AUTH_REDIRECT_URI),
                URLQueryItem(name: "client_id", value: Constants.API_CLIENT_ID),
                URLQueryItem(name: "code_verifier", value: pkceVerifier),
            ]
        )
        try cacheToken(authResponse: response)
    }
    
    static func refreshToken() async throws {
        let lastRefreshToken = String(
            decoding: try Musubi.Storage.Keychain.retrieve(keyName: .oauthRefreshToken),
            as: UTF8.self
        )
        let response = try await requestToken(
            queryItems: [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: lastRefreshToken),
                URLQueryItem(name: "client_id", value: Constants.API_CLIENT_ID),
            ]
        )
        try cacheToken(authResponse: response)
    }
    
    private static func requestToken(queryItems: [URLQueryItem]) async throws -> AuthResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded ", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = queryItems
        request.httpBody = components.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // TODO: consider showing auth webview if old access token given for refreshing was expired
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Spotify.AuthError.any(detail: "unable to interpret response to requestToken")
        }
        guard (httpResponse.statusCode == 200) else {
            throw Spotify.AuthError.any(detail: "requestToken errored: \(httpResponse.statusCode)")
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
}
