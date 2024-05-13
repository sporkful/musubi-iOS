// MusubiUserManager.swift

import Foundation

extension Musubi {
    @Observable
    class UserManager {
        private init() { }
        static let shared = UserManager()
        
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
                URLQueryItem(name: "client_id", value: SPOTIFY_CLIENT_ID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: REDIRECT),
    //            URLQueryItem(name: "state", value: ),
                URLQueryItem(name: "scope", value: SpotifyRequests.ACCESS_SCOPES_STR),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: pkceChallenge),
            ]
            
            return URLRequest(url: components.url!)
        }
        
        @MainActor
        func handleNewLogin(authCode: String, pkceVerifier: String) async throws {
            try await fetchOAuthToken(authCode: authCode, pkceVerifier: pkceVerifier)
            self.currentUser = User(spotifyInfo: try await SpotifyRequests.Read.loggedInUser())
        }
        
        func getAuthToken() async throws -> String {
            try await refreshOAuthToken()
            return retrieveOAuthToken()
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
                    URLQueryItem(name: "redirect_uri", value: REDIRECT),
                    URLQueryItem(name: "client_id", value: SPOTIFY_CLIENT_ID),
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
                    URLQueryItem(name: "client_id", value: SPOTIFY_CLIENT_ID),
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
                throw SpotifyRequests.Error.auth(detail: "unable to interpret response to requestOAuthToken")
            }
            guard (httpResponse.statusCode == 200) else {
                throw SpotifyRequests.Error.auth(detail: "requestOAuthToken errored: \(httpResponse.statusCode)")
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
