// MusubiUserManager.swift

import Foundation

extension Musubi {
    @Observable
    class User: Identifiable {
        let spotifyInfo: Spotify.LoggedInUser
        
        private(set) var localClones: [RepositoryHandle]
        
        var id: Spotify.ID { spotifyInfo.id }
        
        private var localBaseDir: URL {
            URL.libraryDirectory
                .appending(path: "MusubiLocal", directoryHint: .isDirectory)
                .appending(path: "Users", directoryHint: .isDirectory)
                .appending(path: self.id, directoryHint: .isDirectory)
                .appending(path: "LocalClones", directoryHint: .isDirectory)
        }
        
        init?(spotifyInfo: Spotify.LoggedInUser) {
            self.spotifyInfo = spotifyInfo
            self.localClones = []
            
            do {
                if Musubi.Storage.LocalFS.doesDirExist(at: self.localBaseDir) {
                    self.localClones = try Musubi.Storage.LocalFS.contentsOf(dirURL: self.localBaseDir)
                        .map { url in url.lastPathComponent }
                        .map { playlistID in
                            Musubi.RepositoryHandle(
                                userID: self.spotifyInfo.id,
                                playlistID: playlistID
                            )
                        }
                } else {
                    try Musubi.Storage.LocalFS.createNewDir(
                        at: self.localBaseDir,
                        withIntermediateDirectories: true
                    )
                }
                
                // TODO: create Musubi cloud account for this Spotify user if doesn't exist
                // TODO: start playback controller if this is a premium user
            } catch {
                print("[Musubi::User] failed to init user for \(spotifyInfo.display_name)")
                return nil
            }
        }
    }
}

extension Musubi {
    @Observable
    class UserManager {
        private(set) var currentUser: Musubi.User? = nil
        
        @MainActor
        func logOut() {
            self.clearOAuthCache()
            self.currentUser = nil
        }
        
        func createWebLoginRequest(pkceChallenge: String) -> URLRequest {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "accounts.spotify.com"
            components.path = "/authorize"
            components.queryItems = [
                URLQueryItem(name: "client_id", value: SpotifyConstants.API_CLIENT_ID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: SpotifyConstants.OAUTH_DUMMY_REDIRECT_URI),
    //            URLQueryItem(name: "state", value: ),
                URLQueryItem(name: "scope", value: SpotifyConstants.ACCESS_SCOPES_STR),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: pkceChallenge),
            ]
            
            return URLRequest(url: components.url!)
        }
        
        @MainActor
        func handleNewLogin(authCode: String, pkceVerifier: String) async throws {
            try await fetchOAuthToken(authCode: authCode, pkceVerifier: pkceVerifier)
            
            var currentUserRequest = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
            currentUserRequest.httpMethod = "GET"
            let data = try await makeAuthdSpotifyRequest(request: &currentUserRequest)
            
            self.currentUser = User(
                spotifyInfo: try JSONDecoder().decode(Spotify.LoggedInUser.self, from: data)
            )
        }
        
        func makeAuthdSpotifyRequest(request: inout URLRequest) async throws -> Data {
            try await refreshOAuthToken()
            request.setValue(
                "Bearer \(retrieveOAuthToken())",
                forHTTPHeaderField: "Authorization"
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Spotify.RequestError.response(detail: "unable to parse response as HTTP")
            }
            guard SpotifyConstants.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode) else {
                // TODO: auto log out on error code 401?
                throw Spotify.RequestError.response(detail: "failed - \(httpResponse.statusCode)")
            }
            return data
        }
        
        private let TOKEN_EXPIRATION_BUFFER: TimeInterval = 300
        
        private struct OAuthResponse: Codable {
            let access_token: String
            let expires_in: Int
            let refresh_token: String?
            let scope: String
            let token_type: String
        }
        
        private func fetchOAuthToken(authCode: String, pkceVerifier: String) async throws {
            let response = try await requestOAuthToken(
                queryItems: [
                    URLQueryItem(name: "grant_type", value: "authorization_code"),
                    URLQueryItem(name: "code", value: authCode),
                    URLQueryItem(name: "redirect_uri", value: SpotifyConstants.OAUTH_DUMMY_REDIRECT_URI),
                    URLQueryItem(name: "client_id", value: SpotifyConstants.API_CLIENT_ID),
                    URLQueryItem(name: "code_verifier", value: pkceVerifier),
                ]
            )
            
            cacheOAuthToken(response: response)
        }
        
        private func refreshOAuthToken() async throws {
            let expirationDate = retrieveOAuthExpirationDate()
            if Date.now.addingTimeInterval(TOKEN_EXPIRATION_BUFFER) < expirationDate {
                return
            }
            
            let lastRefreshToken = retrieveOAuthRefreshToken()
            let response = try await requestOAuthToken(
                queryItems: [
                    URLQueryItem(name: "grant_type", value: "refresh_token"),
                    URLQueryItem(name: "refresh_token", value: lastRefreshToken),
                    URLQueryItem(name: "client_id", value: SpotifyConstants.API_CLIENT_ID),
                ]
            )
            
            cacheOAuthToken(response: response)
        }
        
        private func requestOAuthToken(queryItems: [URLQueryItem]) async throws -> OAuthResponse {
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
            return try JSONDecoder().decode(OAuthResponse.self, from: data)
        }
        
        private func cacheOAuthToken(response: OAuthResponse) {
            save(oauthToken: response.access_token)
            if let refresh_token = response.refresh_token {
                save(oauthRefreshToken: refresh_token)
            }
            let newExpirationDate = Date.now.addingTimeInterval(TimeInterval(response.expires_in))
            save(oauthExpirationDate: newExpirationDate)
        }
        
        // TODO: can we make this more generic / reduce code duplication? (see eof)

        private typealias Keychain = Musubi.Storage.Keychain
        private typealias KeyIdentifier = Keychain.KeyIdentifier
        
        private func clearOAuthCache() {
            try! Keychain.delete(keyIdentifier: KeyIdentifier(keyName: .oauthToken))
            try! Keychain.delete(keyIdentifier: KeyIdentifier(keyName: .oauthRefreshToken))
            try! Keychain.delete(keyIdentifier: KeyIdentifier(keyName: .oauthExpirationDate))
        }
        
        private func save(oauthToken: String) {
            do {
                try Keychain.save(
                    keyIdentifier: KeyIdentifier(keyName: .oauthToken),
                    value: Data(oauthToken.utf8)
                )
            } catch {
                Task { await self.logOut() }
            }
        }
        
        private func save(oauthRefreshToken: String) {
            do {
                try Keychain.save(
                    keyIdentifier: KeyIdentifier(keyName: .oauthRefreshToken),
                    value: Data(oauthRefreshToken.utf8)
                )
            } catch {
                Task { await self.logOut() }
            }
        }
        
        private func save(oauthExpirationDate: Date) {
            do {
                let rawDate = oauthExpirationDate.timeIntervalSince1970
                try Keychain.save(
                    keyIdentifier: KeyIdentifier(keyName: .oauthExpirationDate),
                    value: withUnsafeBytes(of: rawDate) { Data($0) }
                )
            } catch {
                Task { await self.logOut() }
            }
        }
        
        private func retrieveOAuthToken() -> String {
            do {
                let data = try Keychain.retrieve(keyIdentifier: KeyIdentifier(keyName: .oauthToken))
                return String(decoding: data, as: UTF8.self)
            } catch {
                Task { await self.logOut() }
                return ""
            }
        }
        
        private func retrieveOAuthRefreshToken() -> String {
            do {
                let data = try Keychain.retrieve(keyIdentifier: KeyIdentifier(keyName: .oauthRefreshToken))
                return String(decoding: data, as: UTF8.self)
            } catch {
                Task { await self.logOut() }
                return ""
            }
        }
        
        private func retrieveOAuthExpirationDate() -> Date {
            do {
                let data = try Keychain.retrieve(keyIdentifier: KeyIdentifier(keyName: .oauthExpirationDate))
                return Date(timeIntervalSince1970: data.withUnsafeBytes({ $0.load(as: Double.self) }))
            } catch {
                Task { await self.logOut() }
                return Date.distantPast
            }
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
}
