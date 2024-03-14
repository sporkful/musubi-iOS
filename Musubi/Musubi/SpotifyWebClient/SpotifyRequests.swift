// SpotifyRequests.swift

import Foundation

extension Spotify.Requests {
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
            throw Spotify.RequestError.creation(detail: "given request path is invalid")
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.spotify.com"
        components.path = "/v1" + path
        components.queryItems = queryItems
        guard let url = components.url else {
            throw Spotify.RequestError.creation(detail: "failed to create valid request URL")
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
            throw Spotify.RequestError.other(detail: "failed to convert html to plaintext")
        }
        return attributedString.string
    }
}

extension Spotify.Requests.Read {
    private typealias Requests = Spotify.Requests
    private typealias HTTPMethod = Requests.HTTPMethod
    
    private static func makeAuthenticatedRequest<T: SpotifyViewModel>(
        request: inout URLRequest,
        userManager: Musubi.UserManager
    ) async throws -> T {
        let data = try await userManager.makeAuthenticatedRequest(request: &request)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private static func multipageList<T: SpotifyListPage>(
        firstPage: T,
        userManager: Musubi.UserManager
    ) async throws -> [SpotifyViewModel] {
        var currentPage = firstPage
        var items = currentPage.items
        while let nextPageURLString = currentPage.next,
              let nextPageURL = URL(string: nextPageURLString)
        {
            // TODO: remove this print
            print("fetching page at " + nextPageURLString)
            var request = try Requests.createRequest(type: HTTPMethod.GET, url: nextPageURL)
            currentPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
            items.append(contentsOf: currentPage.items)
        }
        return items
    }
    
    // Intended to reduce memory usage, including intermediate spikes, so do not just call
    // `multipageList` followed by a map operation.
    private static func multipageListIDs<T: SpotifyListPage>(
        firstPage: T,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.ID] {
        var currentPage = firstPage
        var items: [Spotify.Model.ID] = currentPage.items.map { $0.id }
        while let nextPageURLString = currentPage.next,
              let nextPageURL = URL(string: nextPageURLString)
        {
            // TODO: remove this print
            print("fetching page at " + nextPageURLString)
            var request = try Requests.createRequest(type: HTTPMethod.GET, url: nextPageURL)
            currentPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
            items.append(contentsOf: currentPage.items.map { $0.id })
        }
        return items
    }
    
    static func audioTrack(
        audioTrackID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Model.AudioTrack {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/tracks/" + audioTrackID
        )
        return try await makeAuthenticatedRequest(request: &request, userManager: userManager)
    }
    
    static func artist(
        artistID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Model.Artist {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID
        )
        return try await makeAuthenticatedRequest(request: &request, userManager: userManager)
    }
    
    static func album(
        albumID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Model.Album {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID
        )
        return try await makeAuthenticatedRequest(request: &request, userManager: userManager)
    }
    
    static func playlist(
        playlistID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Model.Playlist {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID
        )
        return try await makeAuthenticatedRequest(request: &request, userManager: userManager)
    }
    
    static func albumTracklist(
        albumID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.AudioTrack] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Model.Album.AudioTrackListPage
        firstPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        let tracklist = try await multipageList(firstPage: firstPage, userManager: userManager)
        guard let tracklist = tracklist as? [Spotify.Model.AudioTrack] else {
            throw Spotify.RequestError.other(detail: "DEVERROR(?) albumTracklist multipage types")
        }
        return tracklist
    }
    
    static func playlistTracklist(
        playlistID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.AudioTrack] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Model.Playlist.AudioTrackListPage
        firstPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        let tracklist = try await multipageList(firstPage: firstPage, userManager: userManager)
        guard let tracklist = tracklist as? [Spotify.Model.Playlist.AudioTrackItem] else {
            throw Spotify.RequestError.other(detail: "DEVERROR(?) playlistTracklist multipage types")
        }
        return tracklist.map { $0.track }
    }
    
    static func artistAlbums(
        artistID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.Album] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/albums",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Model.Artist.AlbumListPage
        firstPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        let albumlist = try await multipageList(firstPage: firstPage, userManager: userManager)
        guard let albumlist = albumlist as? [Spotify.Model.Album] else {
            throw Spotify.RequestError.other(detail: "DEVERROR(?) artistAlbums multipage types")
        }
        return albumlist
    }
    
    // TODO: why does this require market query
    static func artistTopTracks(
        artistID: String,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.ID] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/top-tracks",
            queryItems: [URLQueryItem(name: "market", value: "US")]
        )
        let topTracks: Spotify.Model.Artist.TopTracks
        topTracks = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        return topTracks.tracks.map({ $0.id })
    }
    
    static func search(
        query: String,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Model.SearchResults {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "artist,album,playlist,track"),
                URLQueryItem(name: "limit", value: "5")
            ]
        )
        return try await makeAuthenticatedRequest(request: &request, userManager: userManager)
    }
}
