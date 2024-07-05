// SpotifyRequests.swift

import Foundation
import SwiftUI // for UIImage

// namespaces
struct SpotifyRequests {
    private init() { }
    
    struct Read {
        private init() { }
    }
    
    struct Write {
        private init() { }
    }
    
    struct Playback {
        private init() { }
    }
    
    enum Error: LocalizedError {
        case response(httpStatusCode: Int, retryAfter: Int?)
        case auth(detail: String)
        case request(detail: String)
        case parsing(detail: String)
        case DEV(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .response(httpStatusCode, retryAfter): """
                    failed with status code \(httpStatusCode) - retry after \(retryAfter ?? -1))
                    """
                case let .auth(detail): "(auth) \(detail)"
                case let .request(detail): "(request) \(detail)"
                case let .parsing(detail): "(misc parsing) \(detail)"
                case let .DEV(detail): "(DEV) \(detail)"
            }
            return "[Spotify::Request] \(description)"
        }
    }
}

extension SpotifyRequests {
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/scopes
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
        "user-read-private"
    ]
    
    /// Reference:
    /// https://developer.spotify.com/documentation/web-api/concepts/api-calls
    static let HTTP_SUCCESS_CODES = Set([200, 201, 202, 204])
}

extension SpotifyRequests {
    enum HTTPMethod: String {
        case GET, PUT, POST, DELETE
    }
    
    static func makeRequest<Response: Decodable>(
        type: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        jsonBody: Data? = nil
    ) async throws -> Response {
        guard path.first == "/" else {
            throw Error.request(detail: "given request path is invalid")
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.spotify.com"
        components.path = "/v1" + path
        components.queryItems = queryItems
        guard let url = components.url else {
            throw Error.request(detail: "failed to create valid request URL")
        }
        
        return try await makeRequest(
            type: type,
            url: url,
            jsonBody: jsonBody
        )
    }
    
    static func makeRequest<Response: Decodable>(
        type: HTTPMethod,
        url: URL,
        jsonBody: Data? = nil
    ) async throws -> Response {
        let responseData = try await makeRequest(
            type: type,
            url: url,
            jsonBody: jsonBody
        )
        return try JSONDecoder().decode(Response.self, from: responseData)
    }
    
    static func makeRequest(
        type: HTTPMethod,
        url: URL,
        jsonBody: Data? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = type.rawValue
        request.timeoutInterval = 30
        
        if let jsonBody = jsonBody {
            request.httpBody = jsonBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        request.setValue(
            "Bearer \(try await Musubi.UserManager.shared.getAuthToken())",
            forHTTPHeaderField: "Authorization"
        )
        
        let (responseData, responseMetadata) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = responseMetadata as? HTTPURLResponse else {
            throw SpotifyRequests.Error.parsing(detail: "unable to parse response metadata as HTTP")
        }
        guard HTTP_SUCCESS_CODES.contains(httpResponse.statusCode) else {
            // TODO: auto log out on error code 401?
            // TODO: handle rate limiting gracefully / notify user
            if httpResponse.statusCode == 429 {
                print("SPOTIFY RATE LIMITED - RETRY AFTER \(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "")")
            }
            throw SpotifyRequests.Error.response(
                httpStatusCode: httpResponse.statusCode,
                retryAfter: Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "-1")
            )
        }
        
        return responseData
    }
    
    private static func htmlToPlaintext(html: String) throws -> String {
        let attributedString = try? NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        guard let attributedString = attributedString else {
            throw Error.parsing(detail: "failed to convert html to plaintext")
        }
        return attributedString.string
    }
}

extension SpotifyRequests.Read {
    private typealias HTTPMethod = SpotifyRequests.HTTPMethod
    
    static func loggedInUser() async throws -> Spotify.LoggedInUser {
        return try await SpotifyRequests.makeRequest(
            type: .GET,
            url: URL(string: "https://api.spotify.com/v1/me")!
        )
    }
    
    // TODO: transform into AsyncStream
    static func restOfList<Page: SpotifyListPage>(firstPage: Page) async throws -> [Page.Item] {
        var currentPage = firstPage
//        var items = currentPage.items
        var items: [Page.Item] = []
        while let nextPageURLString = currentPage.next,
              let nextPageURL = URL(string: nextPageURLString)
        {
            currentPage = try await SpotifyRequests.makeRequest(type: HTTPMethod.GET, url: nextPageURL)
            items.append(contentsOf: currentPage.items)
        }
        return items
    }
    
    static func audioTrack(audioTrackID: Spotify.ID) async throws -> Spotify.AudioTrack {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/tracks/" + audioTrackID
        )
    }
    
    private struct AudioTracks: Codable {
        let tracks: [Spotify.AudioTrack]
    }
    
    /// - Parameter audioTrackIDs: comma-separated with no spaces, max 50
    private static func audioTracks(audioTrackIDs: String) async throws -> [Spotify.AudioTrack] {
        if audioTrackIDs.isEmpty {
            return []
        }
        let audioTracks: Self.AudioTracks = try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/tracks",
            queryItems: [URLQueryItem(name: "ids", value: audioTrackIDs)]
        )
        return audioTracks.tracks
    }
    
    /// - Parameter audioTrackIDs: comma-separated with no spaces, no max limit
    static func audioTracks(audioTrackIDs: String) -> AsyncThrowingStream<[Spotify.AudioTrack], Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var numCommasSeen = 0
                    var currentRangeStartIndex = audioTrackIDs.startIndex
                    for index in audioTrackIDs.indices {
                        if audioTrackIDs[index] == "," {
                            numCommasSeen += 1
                            if numCommasSeen % 50 == 0 {
                                continuation.yield(
                                    try await SpotifyRequests.Read.audioTracks(
                                        audioTrackIDs: String(audioTrackIDs[currentRangeStartIndex..<index])
                                    )
                                )
                                currentRangeStartIndex = audioTrackIDs.index(after: index)
                            }
                        }
                    }
                    if !(audioTrackIDs.last == "," && numCommasSeen % 50 == 0) {
                        continuation.yield(
                            try await SpotifyRequests.Read.audioTracks(
                                audioTrackIDs: String(audioTrackIDs[currentRangeStartIndex...])
                            )
                        )
                    }
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.finish()
            }
        }
    }

    static func artistMetadata(artistID: Spotify.ID) async throws -> Spotify.ArtistMetadata {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID
        )
    }
    
    static func albumMetadata(albumID: Spotify.ID) async throws -> Spotify.AlbumMetadata {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID
        )
    }
    
    static func playlistMetadata(playlistID: Spotify.ID) async throws -> Spotify.PlaylistMetadata {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID,
            queryItems: [URLQueryItem(name: "fields", value: "id,description,followers,images,name,owner,snapshot_id")]
        )
    }
    
    static func albumFirstAudioTrackPage(albumID: Spotify.ID) async throws -> Spotify.AlbumAudioTrackPage {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
    }
    
    static func albumTrackListFull(albumID: Spotify.ID) async throws -> [Spotify.AudioTrack] {
        let firstPage = try await albumFirstAudioTrackPage(albumID: albumID)
        let restOfTrackList = try await restOfList(firstPage: firstPage)
        return firstPage.items + restOfTrackList
    }
    
    static func playlistFirstAudioTrackPage(playlistID: Spotify.ID) async throws -> Spotify.PlaylistAudioTrackPage {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
    }
    
    static func playlistTrackListFull(playlistID: Spotify.ID) async throws -> [Spotify.AudioTrack] {
        let firstPage = try await playlistFirstAudioTrackPage(playlistID: playlistID)
        let restOfTrackList = try await restOfList(firstPage: firstPage)
        return (firstPage.items + restOfTrackList).map({ $0.track })
    }
    
    static func artistDiscographyPreview(artistID: Spotify.ID) async throws -> [Spotify.AlbumMetadata] {
        let page: Spotify.ArtistAlbumPage = try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/albums",
            queryItems: [URLQueryItem(name: "limit", value: "5")]
        )
        return page.items
    }
    
    static func artistDiscographyFull(artistID: Spotify.ID) async throws -> [Spotify.AlbumMetadata] {
        let firstPage: Spotify.ArtistAlbumPage = try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/albums",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let restOfAlbumList = try await restOfList(firstPage: firstPage)
        return firstPage.items + restOfAlbumList
    }
    
    // TODO: why does this require market query
    static func artistTopTracks(artistID: String) async throws -> [Spotify.AudioTrack] {
        let topTracks: Spotify.ArtistTopTracks = try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/top-tracks",
            queryItems: [
                URLQueryItem(
                    name: "market",
                    value: Musubi.UserManager.shared.currentUser?.spotifyInfo.country ?? "US"
                )
            ]
        )
        return topTracks.tracks
    }
    
    static func search(query: String) async throws -> Spotify.SearchResults {
        return try await SpotifyRequests.makeRequest(
            type: HTTPMethod.GET,
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "artist,album,playlist,track"),
                URLQueryItem(name: "limit", value: "5")
            ]
        )
    }
    
    // TODO: figure out why adding auth token like in `makeRequest` above causes this to fail
    static func image(url: URL) async throws -> UIImage {
        let (data, responseMetadata) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let httpResponse = responseMetadata as? HTTPURLResponse else {
            throw SpotifyRequests.Error.parsing(detail: "unable to parse response metadata as HTTP")
        }
        guard SpotifyRequests.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode) else {
            // TODO: handle rate limiting gracefully / notify user
            if httpResponse.statusCode == 429 {
                print("SPOTIFY RATE LIMITED - RETRY AFTER \(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "")")
            }
            throw SpotifyRequests.Error.response(
                httpStatusCode: httpResponse.statusCode,
                retryAfter: Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "-1")
            )
        }
        guard let image = UIImage(data: data) else {
            throw SpotifyRequests.Error.parsing(detail: "failed to init UIImage from response data")
        }
        return image
    }
}

extension SpotifyRequests.Write {
    private typealias HTTPMethod = SpotifyRequests.HTTPMethod
    
    // TODO: queue operations with enforced ordering
    actor Session {
        let playlistID: Spotify.ID
        var lastSnapshotID: String
        
        init(playlistID: Spotify.ID, lastSnapshotID: String) {
            self.playlistID = playlistID
            self.lastSnapshotID = lastSnapshotID
        }
        
        private struct ResponseBody: Decodable {
            let snapshot_id: String
        }
        
        private func uri(audioTrackID: Spotify.ID) -> String {
            return "spotify:track:\(audioTrackID)"
        }
        
        private struct InsertionRequestBody: Encodable {
            let uris: [String]
            let position: Int
        }
        
        func insert(audioTrackID: Spotify.ID, at position: Int) async throws {
            let response: ResponseBody = try await SpotifyRequests.makeRequest(
                type: HTTPMethod.POST,
                path: "/playlists/" + playlistID + "/tracks",
                jsonBody: JSONEncoder().encode(
                    InsertionRequestBody(
                        uris: [uri(audioTrackID: audioTrackID)],
                        position: position
                    )
                )
            )
            self.lastSnapshotID = response.snapshot_id
        }
        
        private struct RemovalRequestBody: Encodable {
            let positions: [Int]
            let snapshot_id: String
        }
        
        func remove(at position: Int) async throws {
            let response: ResponseBody = try await SpotifyRequests.makeRequest(
                type: HTTPMethod.DELETE,
                path: "/playlists/" + playlistID + "/tracks",
                jsonBody: JSONEncoder().encode(
                    RemovalRequestBody(
                        positions: [position],
                        snapshot_id: self.lastSnapshotID
                    )
                )
            )
            self.lastSnapshotID = response.snapshot_id
        }
        
        private struct MoveRequestBody: Encodable {
            let range_start: Int
            let insert_before: Int
            let range_length: Int
            let snapshot_id: String
            
            init(removalOffset: Int, insertionOffset: Int, snapshotID: String) {
                self.snapshot_id = snapshotID
                self.range_length = 1
                self.range_start = removalOffset
                
                // Account for mismatch between Spotify APIs and Swift's CollectionDifference.
                // https://developer.spotify.com/documentation/web-api/reference/reorder-or-replace-playlists-tracks
                if removalOffset < insertionOffset {
                    self.insert_before = insertionOffset + 1
                } else {
                    self.insert_before = insertionOffset
                }
            }
        }
        
        func move(removalOffset: Int, insertionOffset: Int) async throws {
            if removalOffset == insertionOffset {
                return
            }
            
            let response: ResponseBody = try await SpotifyRequests.makeRequest(
                type: HTTPMethod.PUT,
                path: "/playlists/" + playlistID + "/tracks",
                jsonBody: JSONEncoder().encode(
                    MoveRequestBody(
                        removalOffset: removalOffset,
                        insertionOffset: insertionOffset,
                        snapshotID: self.lastSnapshotID
                    )
                )
            )
            self.lastSnapshotID = response.snapshot_id
        }
    }
}
