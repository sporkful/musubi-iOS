// SpotifyWebClient.swift

import Foundation

extension Spotify {
    @MainActor
    static func logOut(userManager: Musubi.UserManager) {
        clearOAuthCache()
        userManager.loggedInUser = nil
    }
    
    static func createWebLoginRequest(pkceChallenge: String) -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "accounts.spotify.com"
        components.path = "/authorize"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.API_CLIENT_ID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Constants.OAUTH_DUMMY_REDIRECT_URI),
//            URLQueryItem(name: "state", value: ),
            URLQueryItem(name: "scope", value: Constants.ACCESS_SCOPES_STR),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: pkceChallenge),
        ]
        
        return URLRequest(url: components.url!)
    }
    
    @MainActor
    static func handleNewLogin(
        authCode: String,
        pkceVerifier: String,
        userManager: Musubi.UserManager
    ) async throws {
        try await fetchOAuthToken(
            authCode: authCode,
            pkceVerifier: pkceVerifier,
            userManager: userManager
        )
        
        var currentUserRequest = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        currentUserRequest.httpMethod = "GET"
        let data = try await makeAuthenticatedRequest(
            request: &currentUserRequest,
            userManager: userManager
        )
        
        userManager.loggedInUser = try JSONDecoder().decode(Spotify.LoggedInUser.self, from: data)
    }
    
    static func makeAuthenticatedRequest(
        request: inout URLRequest,
        userManager: Musubi.UserManager
    ) async throws -> Data {
        try await refreshOAuthToken(userManager: userManager)
        request.setValue(
            "Bearer \(retrieveOAuthToken(userManager: userManager))",
            forHTTPHeaderField: "Authorization"
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Spotify.RequestError.response(detail: "unable to parse response as HTTP")
        }
        guard Constants.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode) else {
            // TODO: auto log out on error code 401?
            throw Spotify.RequestError.response(detail: "failed - \(httpResponse.statusCode)")
        }
        return data
    }
    
    private static func fetchOAuthToken(
        authCode: String,
        pkceVerifier: String,
        userManager: Musubi.UserManager
    ) async throws {
        let response = try await requestOAuthToken(
            queryItems: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: authCode),
                URLQueryItem(name: "redirect_uri", value: Constants.OAUTH_DUMMY_REDIRECT_URI),
                URLQueryItem(name: "client_id", value: Constants.API_CLIENT_ID),
                URLQueryItem(name: "code_verifier", value: pkceVerifier),
            ]
        )
        
        cacheOAuthToken(response: response, userManager: userManager)
    }
    
    private static func refreshOAuthToken(userManager: Musubi.UserManager) async throws {
        let expirationDate = retrieveOAuthExpirationDate(userManager: userManager)
        if Date.now.addingTimeInterval(Constants.TOKEN_EXPIRATION_BUFFER) < expirationDate {
            return
        }
        
        let lastRefreshToken = retrieveOAuthRefreshToken(userManager: userManager)
        let response = try await requestOAuthToken(
            queryItems: [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: lastRefreshToken),
                URLQueryItem(name: "client_id", value: Constants.API_CLIENT_ID),
            ]
        )
        
        cacheOAuthToken(response: response, userManager: userManager)
    }
    
    private static func requestOAuthToken(queryItems: [URLQueryItem]) async throws -> Spotify.OAuthResponse {
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
    
    private static func cacheOAuthToken(
        response: Spotify.OAuthResponse,
        userManager: Musubi.UserManager
    ) {
        save(oauthToken: response.access_token, userManager: userManager)
        if let refresh_token = response.refresh_token {
            save(oauthRefreshToken: refresh_token, userManager: userManager)
        }
        let newExpirationDate = Date.now.addingTimeInterval(TimeInterval(response.expires_in))
        save(oauthExpirationDate: newExpirationDate, userManager: userManager)
    }
}

extension Spotify.Constants {
    fileprivate static let TOKEN_EXPIRATION_BUFFER: TimeInterval = 300
    fileprivate static let OAUTH_DUMMY_REDIRECT_URI = "https://github.com/musubi-app/musubi-iOS"
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/scopes
    /// As a rule of thumb, Musubi only gives itself write access to things under its version control.
    fileprivate static var ACCESS_SCOPES_STR: String { ACCESS_SCOPES.joined(separator: " ") }
    fileprivate static let ACCESS_SCOPES = [
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
    fileprivate static let HTTP_SUCCESS_CODES = Set([200, 201, 202, 204])
}

// MARK: OAuth caching
// TODO: can we make this more generic / reduce code duplication? (see eof)
// note we can't make these static funcs since logOut is tied to an instance of SpotifyWebClient
extension Spotify {
    private typealias Keychain = Musubi.Storage.Keychain
    private typealias KeyIdentifier = Keychain.KeyIdentifier
    
    private static func save(oauthToken: String, userManager: Musubi.UserManager) {
        do {
            try Keychain.save(
                keyIdentifier: KeyIdentifier(keyName: .oauthToken),
                value: Data(oauthToken.utf8)
            )
        } catch {
            Task { await logOut(userManager: userManager) }
        }
    }
    
    private static func save(oauthRefreshToken: String, userManager: Musubi.UserManager) {
        do {
            try Keychain.save(
                keyIdentifier: KeyIdentifier(keyName: .oauthRefreshToken),
                value: Data(oauthRefreshToken.utf8)
            )
        } catch {
            Task { await logOut(userManager: userManager) }
        }
    }
    
    private static func save(oauthExpirationDate: Date, userManager: Musubi.UserManager) {
        do {
            let rawDate = oauthExpirationDate.timeIntervalSince1970
            try Keychain.save(
                keyIdentifier: KeyIdentifier(keyName: .oauthExpirationDate),
                value: withUnsafeBytes(of: rawDate) { Data($0) }
            )
        } catch {
            Task { await logOut(userManager: userManager) }
        }
    }
    
    private static func retrieveOAuthToken(userManager: Musubi.UserManager) -> String {
        do {
            let data = try Keychain.retrieve(keyIdentifier: KeyIdentifier(keyName: .oauthToken))
            return String(decoding: data, as: UTF8.self)
        } catch {
            Task { await logOut(userManager: userManager) }
            return ""
        }
    }
    
    private static func retrieveOAuthRefreshToken(userManager: Musubi.UserManager) -> String {
        do {
            let data = try Keychain.retrieve(keyIdentifier: KeyIdentifier(keyName: .oauthRefreshToken))
            return String(decoding: data, as: UTF8.self)
        } catch {
            Task { await logOut(userManager: userManager) }
            return ""
        }
    }
    
    private static func retrieveOAuthExpirationDate(userManager: Musubi.UserManager) -> Date {
        do {
            let data = try Keychain.retrieve(keyIdentifier: KeyIdentifier(keyName: .oauthExpirationDate))
            return Date(timeIntervalSince1970: data.withUnsafeBytes({ $0.load(as: Double.self) }))
        } catch {
            Task { await logOut(userManager: userManager) }
            return Date.distantPast
        }
    }
    
    private static func clearOAuthCache() {
        try! Keychain.delete(keyIdentifier: KeyIdentifier(keyName: .oauthToken))
        try! Keychain.delete(keyIdentifier: KeyIdentifier(keyName: .oauthRefreshToken))
        try! Keychain.delete(keyIdentifier: KeyIdentifier(keyName: .oauthExpirationDate))
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
