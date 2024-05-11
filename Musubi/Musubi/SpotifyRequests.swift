// SpotifyRequests.swift

import Foundation

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
        case auth(detail: String)
        case request(detail: String)
        case response(detail: String)
        case misc(detail: String)
        case DEV(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .auth(detail): "(auth) \(detail)"
                case let .request(detail): "(request) \(detail)"
                case let .response(detail): "(response) \(detail)"
                case let .misc(detail): "(misc) \(detail)"
                case let .DEV(detail): "(DEV) \(detail)"
            }
            return "[Spotify::Request] \(description)"
        }
    }
}

extension SpotifyRequests {
    private enum HTTPMethod: String {
        case GET, PUT, POST, DELETE
    }
    
    private static func createRequest(
        type: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        bodyData: Data? = nil,
        setContentTypeJSON: Bool = false
    ) throws -> URLRequest {
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
        
        return try createRequest(
            type: type,
            url: url,
            bodyData: bodyData,
            setContentTypeJSON: setContentTypeJSON
        )
    }
    
    private static func createRequest(
        type: HTTPMethod,
        url: URL,
        bodyData: Data? = nil,
        setContentTypeJSON: Bool = false
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = type.rawValue
        if bodyData != nil {
            request.httpBody = bodyData
        }
        if setContentTypeJSON {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.timeoutInterval = 30
        return request
    }
    
    private static func htmlToPlaintext(html: String) throws -> String {
        let attributedString = try? NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        guard let attributedString = attributedString else {
            throw Error.misc(detail: "failed to convert html to plaintext")
        }
        return attributedString.string
    }
}

extension SpotifyRequests.Read {
    private typealias HTTPMethod = SpotifyRequests.HTTPMethod
    
    // TODO: transform into AsyncStream
    static func restOfList<T: SpotifyListPage>(firstPage: T) async throws -> [SpotifyViewModel] {
        var items: [SpotifyViewModel] = []
        var currentPage = firstPage
//        var items = currentPage.items
        while let nextPageURLString = currentPage.next,
              let nextPageURL = URL(string: nextPageURLString)
        {
            var request = try SpotifyRequests.createRequest(type: HTTPMethod.GET, url: nextPageURL)
            let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
            currentPage = try JSONDecoder().decode(T.self, from: data)
            items.append(contentsOf: currentPage.items)
        }
        return items
    }
    
    static func audioTrack(audioTrackID: Spotify.ID) async throws -> Spotify.AudioTrack {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/tracks/" + audioTrackID
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.AudioTrack.self, from: data)
    }
    
    private struct AudioTracks: Codable {
        let tracks: [Spotify.AudioTrack]
    }
    
    // TODO: transform into AsyncStream to allow input without upper bound of 50
    /// - Parameter audioTrackIDs: comma-separated with no spaces, max 50
    static func audioTracks(audioTrackIDs: String) async throws -> [Spotify.AudioTrack] {
        if audioTrackIDs.isEmpty {
            return []
        }
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/tracks",
            queryItems: [URLQueryItem(name: "ids", value: audioTrackIDs)]
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(AudioTracks.self, from: data).tracks
    }

    static func artistMetadata(artistID: Spotify.ID) async throws -> Spotify.ArtistMetadata {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.ArtistMetadata.self, from: data)
    }
    
    static func albumMetadata(albumID: Spotify.ID) async throws -> Spotify.AlbumMetadata {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.AlbumMetadata.self, from: data)
    }
    
    static func playlistMetadata(playlistID: Spotify.ID) async throws -> Spotify.PlaylistMetadata {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID,
            queryItems: [URLQueryItem(name: "fields", value: "id,description,followers,images,name,owner,snapshot_id")]
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.PlaylistMetadata.self, from: data)
    }
    
    static func albumFirstAudioTrackPage(albumID: Spotify.ID) async throws -> Spotify.AlbumAudioTrackPage {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.AlbumAudioTrackPage.self, from: data)
    }
    
    static func albumTrackListFull(albumID: Spotify.ID) async throws -> [Spotify.AudioTrack] {
        let firstPage = try await albumFirstAudioTrackPage(albumID: albumID)
        let restOfTrackList = try await restOfList(firstPage: firstPage)
        guard let restOfTrackList = restOfTrackList as? [Spotify.AudioTrack] else {
            throw SpotifyRequests.Error.DEV(detail: "albumTracklist multipage types")
        }
        return firstPage.items + restOfTrackList
    }
    
    static func playlistFirstAudioTrackPage(playlistID: Spotify.ID) async throws -> Spotify.PlaylistAudioTrackPage {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.PlaylistAudioTrackPage.self, from: data)
    }
    
    static func playlistTrackListFull(playlistID: Spotify.ID) async throws -> [Spotify.PlaylistAudioTrackItem] {
        let firstPage = try await playlistFirstAudioTrackPage(playlistID: playlistID)
        let restOfTrackList = try await restOfList(firstPage: firstPage)
        guard let restOfTrackList = restOfTrackList as? [Spotify.PlaylistAudioTrackItem] else {
            throw SpotifyRequests.Error.DEV(detail: "playlistTracklist multipage types")
        }
        return firstPage.items + restOfTrackList
    }
    
    static func artistAlbums(artistID: Spotify.ID) async throws -> [Spotify.AlbumMetadata] {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/albums",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.ArtistAlbumPage
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        firstPage = try JSONDecoder().decode(Spotify.ArtistAlbumPage.self, from: data)
        let restOfAlbumList = try await restOfList(firstPage: firstPage)
        guard let restOfAlbumList = restOfAlbumList as? [Spotify.AlbumMetadata] else {
            throw SpotifyRequests.Error.DEV(detail: "artistAlbums multipage types")
        }
        return firstPage.items + restOfAlbumList
    }
    
    // TODO: why does this require market query
    static func artistTopTracks(artistID: String) async throws -> [Spotify.ID] {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/top-tracks",
            queryItems: [URLQueryItem(name: "market", value: "US")]
        )
        let topTracks: Spotify.ArtistTopTracks
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        topTracks = try JSONDecoder().decode(Spotify.ArtistTopTracks.self, from: data)
        return topTracks.tracks.map({ $0.id })
    }
    
    static func search(query: String) async throws -> Spotify.SearchResults {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "artist,album,playlist,track"),
                URLQueryItem(name: "limit", value: "5")
            ]
        )
        let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.SearchResults.self, from: data)
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
            var request = try SpotifyRequests.createRequest(
                type: HTTPMethod.POST,
                path: "/playlists/" + playlistID + "/tracks",
                bodyData: JSONEncoder().encode(
                    InsertionRequestBody(
                        uris: [uri(audioTrackID: audioTrackID)],
                        position: position
                    )
                ),
                setContentTypeJSON: true
            )
            let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
            let response = try JSONDecoder().decode(ResponseBody.self, from: data)
            self.lastSnapshotID = response.snapshot_id
        }
        
        private struct RemovalRequestBody: Encodable {
            let positions: [Int]
            let snapshot_id: String
        }
        
        func remove(at position: Int) async throws {
            var request = try SpotifyRequests.createRequest(
                type: HTTPMethod.DELETE,
                path: "/playlists/" + playlistID + "/tracks",
                bodyData: JSONEncoder().encode(
                    RemovalRequestBody(
                        positions: [position],
                        snapshot_id: self.lastSnapshotID
                    )
                ),
                setContentTypeJSON: true
            )
            let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
            let response = try JSONDecoder().decode(ResponseBody.self, from: data)
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
            
            var request = try SpotifyRequests.createRequest(
                type: HTTPMethod.PUT,
                path: "/playlists/" + playlistID + "/tracks",
                bodyData: JSONEncoder().encode(
                    MoveRequestBody(
                        removalOffset: removalOffset,
                        insertionOffset: insertionOffset,
                        snapshotID: self.lastSnapshotID
                    )
                ),
                setContentTypeJSON: true
            )
            let data = try await Musubi.UserManager.shared.makeAuthdSpotifyRequest(request: &request)
            let response = try JSONDecoder().decode(ResponseBody.self, from: data)
            self.lastSnapshotID = response.snapshot_id
        }
    }
}
