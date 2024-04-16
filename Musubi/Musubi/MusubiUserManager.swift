// MusubiUserManager.swift

import Foundation

extension Musubi {
    @Observable
    @MainActor
    class User: Identifiable {
        let spotifyInfo: Spotify.LoggedInUser
        
        typealias LocalClonesIndex = [Musubi.RepositoryReference]
        var localClonesIndex: LocalClonesIndex
        
        nonisolated var id: Spotify.ID { spotifyInfo.id }
        
        init?(spotifyInfo: Spotify.LoggedInUser, userManager: Musubi.UserManager) {
            self.spotifyInfo = spotifyInfo
            self.localClonesIndex = []
            
            do {
                let userClonesDir = Musubi.Storage.LocalFS.USER_CLONES_DIR(userID: self.id)
                let userClonesIndexFile = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: self.id)
                
                if Musubi.Storage.LocalFS.doesFileExist(at: userClonesIndexFile) {
                    self.localClonesIndex = try JSONDecoder().decode(
                        LocalClonesIndex.self,
                        from: Data(contentsOf: userClonesIndexFile)
                    )
                    Task {
                        await refreshClonesExternalMetadata(userManager: userManager)
                    }
                } else {
                    try Musubi.Storage.LocalFS.createNewDir(
                        at: userClonesDir,
                        withIntermediateDirectories: true
                    )
                    try JSONEncoder().encode(self.localClonesIndex).write(to: userClonesIndexFile, options: .atomic)
                }
            } catch {
                print("[Musubi::User] failed to init user for \(spotifyInfo.display_name)")
                return nil
            }
            
            // TODO: start playback polling if this is a premium user (here or when HomeView appears?)
        }
        
        // TODO: better error handling / retries
        func refreshClonesExternalMetadata(userManager: Musubi.UserManager) async {
            // Note that indices into `self.localClonesIndex` are not guaranteed to be stable for
            // the full execution of the for-loop due to the `await`ing of the Spotify request on
            // every iteration. Since this function is meant to be called periodically in the
            // background and we don't need particularly strong consistency guarantees
            // (it deals with Spotify-controlled metadata that we explicitly don't version control),
            // we choose to `break` as soon as we detect that the underlying index has changed from
            // when the function was invoked.
            for i in self.localClonesIndex.indices {
                guard self.localClonesIndex.indices.contains(i) else {
                    break
                }
                let playlistID = self.localClonesIndex[i].handle.playlistID
                guard let spotifyPlaylistMetadata = try? await SpotifyRequests.Read.playlist(
                    playlistID: playlistID,
                    userManager: userManager
                ) else {
                    // The erroring of the Spotify request itself implies nothing about the index.
                    continue
                }
                guard self.localClonesIndex.indices.contains(i),
                      spotifyPlaylistMetadata.id == self.localClonesIndex[i].handle.playlistID
                else {
                    break
                }
                // Avoid triggering unnecessary SwiftUI updates.
                let newExternalMetadata = Musubi.RepositoryExternalMetadata(
                    spotifyPlaylistMetadata: spotifyPlaylistMetadata
                )
                if newExternalMetadata != self.localClonesIndex[i].externalMetadata {
                    self.localClonesIndex[i].externalMetadata = newExternalMetadata
                }
            }
            Task {
                try? await saveClonesIndex()
            }
        }
        
        nonisolated func saveClonesIndex() async throws {
            let userClonesIndexFile = Musubi.Storage.LocalFS.USER_CLONES_INDEX_FILE(userID: self.id)
            try JSONEncoder().encode(await self.localClonesIndex).write(to: userClonesIndexFile, options: .atomic)
        }
        
        // TODO: clean up reference-spaghetti between User and UserManager
        func initOrClone(
            repositoryHandle: Musubi.RepositoryHandle,
            userManager: Musubi.UserManager
        ) async throws {
            if localClonesIndex.contains(where: { $0.handle == repositoryHandle }) {
                throw Musubi.RepositoryError.cloning(detail: "called initOrClone on already cloned repo")
            }
            if repositoryHandle.userID != self.id {
                throw Musubi.RepositoryError.cloning(detail: "called initOrClone on unowned playlist")
            }
            
            let requestBody = InitOrClone_RequestBody(playlistID: repositoryHandle.playlistID)
            var request = try MusubiCloudRequests.createRequest(
                command: .INIT_OR_CLONE,
                bodyData: try Musubi.jsonEncoder().encode(requestBody)
            )
            let responseData = try await userManager.makeAuthdMusubiCloudRequest(request: &request)
            
            try saveClone(
                repositoryHandle: repositoryHandle,
                response: try Musubi.jsonDecoder().decode(Clone_ResponseBody.self, from: responseData)
            )
            
            self.localClonesIndex.append(
                Musubi.RepositoryReference(
                    handle: repositoryHandle,
                    externalMetadata: Musubi.RepositoryExternalMetadata(
                        spotifyPlaylistMetadata: try await SpotifyRequests.Read.playlist(
                            playlistID: repositoryHandle.playlistID,
                            userManager: userManager
                        )
                    )
                )
            )
            // TODO: better error handling here?
            try? await saveClonesIndex()
        }
        
        // TODO: impl
//        func forkOrClone(ownerID: Spotify.ID, playlistID: Spotify.ID, userManager: Musubi.UserManager) async throws {
//
//        }
        
        private func saveClone(repositoryHandle: Musubi.RepositoryHandle, response: Clone_ResponseBody) throws {
            typealias LocalFS = Musubi.Storage.LocalFS
            
            guard let headCommit = response.commits[response.headCommitID],
                  let headBlob = response.blobs[headCommit.blobID]
            else {
                throw Musubi.RepositoryError.cloning(detail: "clone response does not have valid head blob")
            }
            
            let cloneDir = LocalFS.CLONE_DIR(repositoryHandle: repositoryHandle)
            if LocalFS.doesDirExist(at: cloneDir) {
                throw Musubi.RepositoryError.cloning(detail: "tried to clone repo that was already cloned")
            }
            try LocalFS.createNewDir(at: cloneDir, withIntermediateDirectories: true)
            
            for (blobID, blob) in response.blobs {
                try LocalFS.saveGlobalObject(object: blob, objectID: blobID)
            }
            for (commitID, commit) in response.commits {
                try LocalFS.saveGlobalObject(object: commit, objectID: commitID)
            }
            
            try Data(response.headCommitID.utf8).write(
                to: LocalFS.CLONE_HEAD_FILE(repositoryHandle: repositoryHandle),
                options: .atomic
            )
            try Data(headBlob.utf8).write(
                to: LocalFS.CLONE_STAGING_AREA_FILE(repositoryHandle: repositoryHandle),
                options: .atomic
            )
            if let forkParent = response.forkParent {
                let forkParentHandle = Musubi.RepositoryHandle(
                    userID: forkParent.userID,
                    playlistID: forkParent.playlistID
                )
                try JSONEncoder().encode(forkParentHandle).write(
                    to: LocalFS.CLONE_FORK_PARENT_FILE(repositoryHandle: repositoryHandle),
                    options: .atomic
                )
            }
        }
        
        private struct InitOrClone_RequestBody: Encodable {
            let playlistID: String
        }
        
        private struct Clone_ResponseBody: Decodable {
            let commits: [String: Musubi.Model.Commit]
            let blobs: [String: Musubi.Model.Blob]
            
            let headCommitID: String
            let forkParent: RelatedRepository?
            
            struct RelatedRepository: Decodable {
                let userID: String
                let playlistID: String
                // Note omission of remotely-mutable `LatestSyncCommitID`, which is handled by backend.
            }
        }
  
        // TODO: impl
//        func deleteClone(repositoryHandle: Musubi.RepositoryHandle) {
//
//        }
    }
}

// TODO: make this a global singleton (Musubi.UserManager.shared)
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
                spotifyInfo: try JSONDecoder().decode(Spotify.LoggedInUser.self, from: data),
                userManager: self
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
                // TODO: handle rate limiting gracefully / notify user
                throw Spotify.RequestError.response(
                    detail: """
                            failed with status code \(httpResponse.statusCode) - retry after \
                            \(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "")
                            """
                )
            }
            
            return data
        }
        
        func makeAuthdMusubiCloudRequest(request: inout URLRequest) async throws -> Data {
            try await refreshOAuthToken()
            request.setValue(
                retrieveOAuthToken(),
                forHTTPHeaderField: "X-Musubi-SpotifyAuth"
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Musubi.CloudRequestError.any(detail: "unable to parse response as HTTP")
            }
            // TODO: check this
            guard SpotifyConstants.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode) else {
                throw Musubi.CloudRequestError.any(detail: "failed - \(httpResponse.statusCode)")
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
