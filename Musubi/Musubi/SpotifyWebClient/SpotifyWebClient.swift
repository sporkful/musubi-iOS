// SpotifyWebClient.swift

import Foundation

@Observable
class SpotifyWebClient {
    var loggedInUser: Spotify.LoggedInUser?
    
    @MainActor
    func logOut() {
        self.clearOAuthCache()
        self.loggedInUser = nil
    }
    
    func createWebLoginRequest(pkceChallenge: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/authorize")!)
        request.httpMethod = "GET"
//        request.setValue("application/x-www-form-urlencoded ", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyWebClient.API_CLIENT_ID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyWebClient.OAUTH_DUMMY_REDIRECT_URI),
//            URLQueryItem(name: "state", value: ),
            URLQueryItem(name: "scope", value: SpotifyWebClient.ACCESS_SCOPES_STR),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: pkceChallenge),
        ]
        request.httpBody = components.query?.data(using: .utf8)
        
        return request
    }
    
    func handleNewLogin(oauthRedirectedURL: URL?, pkceVerifier: String) async throws {
        guard let oauthRedirectedURL = oauthRedirectedURL
        else {
            throw Spotify.AuthError.any(detail: "failed to obtain oauth-redirected URL")
        }
        guard let authCode = URLComponents(string: oauthRedirectedURL.absoluteString)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
        else {
            throw Spotify.AuthError.any(detail: "oauth-redirected URL did not contain auth code")
        }
        
        try await fetchOAuthToken(authCode: authCode, pkceVerifier: pkceVerifier)
        
        var currentUserRequest = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        currentUserRequest.httpMethod = "GET"
        let data = try await makeAuthenticatedRequest(request: &currentUserRequest)
        
        self.loggedInUser = try JSONDecoder().decode(Spotify.LoggedInUser.self, from: data)
    }
    
    func makeAuthenticatedRequest(request: inout URLRequest) async throws -> Data {
        try await refreshOAuthToken()
        request.setValue("Bearer \(retrieveOAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Spotify.RequestError.response(detail: "unable to parse response as HTTP")
        }
        guard SpotifyWebClient.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode) else {
            // TODO: auto log out on error code 401?
            throw Spotify.RequestError.response(detail: "failed - \(httpResponse.statusCode)")
        }
        return data
    }
    
    private func fetchOAuthToken(authCode: String, pkceVerifier: String) async throws {
        let response = try await requestOAuthToken(
            queryItems: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: authCode),
                URLQueryItem(name: "redirect_uri", value: SpotifyWebClient.OAUTH_DUMMY_REDIRECT_URI),
                URLQueryItem(name: "client_id", value: SpotifyWebClient.API_CLIENT_ID),
                URLQueryItem(name: "code_verifier", value: pkceVerifier),
            ]
        )
        
        cacheOAuth(response: response)
    }
    
    private func refreshOAuthToken() async throws {
        if Date.now.addingTimeInterval(SpotifyWebClient.TOKEN_EXPIRATION_BUFFER) < retrieveOAuthExpirationDate() {
            return
        }
        
        let response = try await requestOAuthToken(
            queryItems: [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: retrieveOAuthRefreshToken()),
                URLQueryItem(name: "client_id", value: SpotifyWebClient.API_CLIENT_ID),
            ]
        )
        
        cacheOAuth(response: response)
    }
    
    private func requestOAuthToken(queryItems: [URLQueryItem]) async throws -> Spotify.OAuthResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded ", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = queryItems
        request.httpBody = components.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // TODO: consider showing auth webview if old access token given for refreshing was expired
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Spotify.AuthError.any(detail: "unable to interpret response to requestOAuthToken")
        }
        guard (httpResponse.statusCode == 200) else {
            throw Spotify.AuthError.any(detail: "requestOAuthToken errored: \(httpResponse.statusCode)")
        }
        return try JSONDecoder().decode(Spotify.OAuthResponse.self, from: data)
    }
    
    private func cacheOAuth(response: Spotify.OAuthResponse) {
        save(oauthToken: response.access_token)
        if let refresh_token = response.refresh_token {
            save(oauthRefreshToken: refresh_token)
        }
        save(oauthExpirationDate: Date.now.addingTimeInterval(TimeInterval(response.expires_in)))
    }
}

// MARK: Constants
extension SpotifyWebClient {
    private static let TOKEN_EXPIRATION_BUFFER: TimeInterval = 300
    private static let OAUTH_DUMMY_REDIRECT_URI = "https://musubi-iOS.com"
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/scopes
    /// As a rule of thumb, Musubi only gives itself write access to things under its version control.
    private static var ACCESS_SCOPES_STR: String { ACCESS_SCOPES.joined(separator: " ") }
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
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/api-calls
    private static let HTTP_SUCCESS_CODES = Set([200, 201, 202, 204])
}

// MARK: OAuth caching
// TODO: can we make this more generic / reduce code duplication? (see eof)
// note we can't make these static funcs since logOut is tied to an instance of SpotifyWebClient
extension SpotifyWebClient {
    private func save(oauthToken: String) {
        do {
            try Musubi.Storage.Keychain.save(
                keyName: .oauthToken,
                value: Data(oauthToken.utf8)
            )
        } catch {
            Task { await logOut() }
        }
    }
    
    private func save(oauthRefreshToken: String) {
        do {
            try Musubi.Storage.Keychain.save(
                keyName: .oauthRefreshToken,
                value: Data(oauthRefreshToken.utf8)
            )
        } catch {
            Task { await logOut() }
        }
    }
    
    private func save(oauthExpirationDate: Date) {
        do {
            let rawDate = oauthExpirationDate.timeIntervalSince1970
            try Musubi.Storage.Keychain.save(
                keyName: .oauthExpirationDate,
                value: withUnsafeBytes(of: rawDate) { Data($0) }
            )
        } catch {
            Task { await logOut() }
        }
    }
    
    private func retrieveOAuthToken() -> String {
        do {
            let data = try Musubi.Storage.Keychain.retrieve(keyName: .oauthToken)
            return String(decoding: data, as: UTF8.self)
        } catch {
            Task { await logOut() }
            return ""
        }
    }
    
    private func retrieveOAuthRefreshToken() -> String {
        do {
            let data = try Musubi.Storage.Keychain.retrieve(keyName: .oauthRefreshToken)
            return String(decoding: data, as: UTF8.self)
        } catch {
            Task { await logOut() }
            return ""
        }
    }
    
    private func retrieveOAuthExpirationDate() -> Date {
        do {
            let data = try Musubi.Storage.Keychain.retrieve(keyName: .oauthExpirationDate)
            return Date(timeIntervalSince1970: data.withUnsafeBytes({ $0.load(as: Double.self) }))
        } catch {
            Task { await logOut() }
            return Date.distantPast
        }
    }
    
    private func clearOAuthCache() {
        try! Musubi.Storage.Keychain.delete(keyName: .oauthToken)
        try! Musubi.Storage.Keychain.delete(keyName: .oauthRefreshToken)
        try! Musubi.Storage.Keychain.delete(keyName: .oauthExpirationDate)
    }
    
//    private enum OAuthCacheable {
//        case token, refreshToken, expirationDate
//
//        var keychainName: Musubi.Storage.Keychain.KeyName {
//            switch self {
//            case .token: .oauthToken
//            case .refreshToken: .oauthRefreshToken
//            case .expirationDate: .oauthExpirationDate
//            }
//        }
//
//        // TODO: does Swift have built-in features to support this? ideally want to just bind
//        // each case to a different type (e.g. token:String, expirationDate:Date)
//        func save<T>(value: T) throws {
//            let typeErrDetail = "(SpotifyWebClient::OAuthCacheable::save) given value has wrong type"
//            switch self {
//            case .token, .refreshToken:
//                guard value is String else {
//                    throw Musubi.DeveloperError.any(detail: typeErrDetail)
//                }
//            case .expirationDate:
//                guard value is Date else {
//                    throw Musubi.DeveloperError.any(detail: typeErrDetail)
//                }
//            }
//
//            let value: Data = switch self {
//            case .token, .refreshToken:
//                Data((value as! String).utf8)
//            case .expirationDate:
//                withUnsafeBytes(of: value) { Data($0) }
//            }
//
//            do {
//                try Musubi.Storage.Keychain.save(
//                    keyName: self.keychainName,
//                    value: value
//                )
//            } catch {
//                Task {
//                    await logOut()
//                }
//            }
//        }
//    }
}
