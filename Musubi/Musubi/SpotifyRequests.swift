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

extension SpotifyRequests.Read {
    private typealias HTTPMethod = SpotifyRequests.HTTPMethod
    
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
            var request = try SpotifyRequests.createRequest(type: HTTPMethod.GET, url: nextPageURL)
            let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
            currentPage = try JSONDecoder().decode(T.self, from: data)
            items.append(contentsOf: currentPage.items)
        }
        return items
    }
    
    // Intended to reduce memory usage, including intermediate spikes, so do not just call
    // `multipageList` followed by a map operation.
    private static func multipageListIDs<T: SpotifyListPage>(
        firstPage: T,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.ID] {
        var currentPage = firstPage
        var items: [Spotify.ID] = currentPage.items.map { $0.id }
        while let nextPageURLString = currentPage.next,
              let nextPageURL = URL(string: nextPageURLString)
        {
            // TODO: remove this print
            print("fetching page at " + nextPageURLString)
            var request = try SpotifyRequests.createRequest(type: HTTPMethod.GET, url: nextPageURL)
            let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
            currentPage = try JSONDecoder().decode(T.self, from: data)
            items.append(contentsOf: currentPage.items.map { $0.id })
        }
        return items
    }
    
    static func audioTrack(
        audioTrackID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.AudioTrack {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/tracks/" + audioTrackID
        )
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.AudioTrack.self, from: data)
    }
    
    static func artist(
        artistID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Artist {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID
        )
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.Artist.self, from: data)
    }
    
    static func album(
        albumID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Album {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID
        )
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.Album.self, from: data)
    }
    
    static func playlist(
        playlistID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.Playlist {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID
        )
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.Playlist.self, from: data)
    }
    
    static func albumTracklist(
        albumID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.AudioTrack] {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Album.AudioTrackListPage
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        firstPage = try JSONDecoder().decode(Spotify.Album.AudioTrackListPage.self, from: data)
        let tracklist = try await multipageList(firstPage: firstPage, userManager: userManager)
        guard let tracklist = tracklist as? [Spotify.AudioTrack] else {
            throw Spotify.RequestError.other(detail: "DEVERROR(?) albumTracklist multipage types")
        }
        return tracklist
    }
    
    static func playlistTracklist(
        playlistID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.AudioTrack] {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Playlist.AudioTrackListPage
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        firstPage = try JSONDecoder().decode(Spotify.Playlist.AudioTrackListPage.self, from: data)
        let tracklist = try await multipageList(firstPage: firstPage, userManager: userManager)
        guard let tracklist = tracklist as? [Spotify.Playlist.AudioTrackItem] else {
            throw Spotify.RequestError.other(detail: "DEVERROR(?) playlistTracklist multipage types")
        }
        return tracklist.map { $0.track }
    }
    
    static func artistAlbums(
        artistID: Spotify.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Album] {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/albums",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Artist.AlbumListPage
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        firstPage = try JSONDecoder().decode(Spotify.Artist.AlbumListPage.self, from: data)
        let albumlist = try await multipageList(firstPage: firstPage, userManager: userManager)
        guard let albumlist = albumlist as? [Spotify.Album] else {
            throw Spotify.RequestError.other(detail: "DEVERROR(?) artistAlbums multipage types")
        }
        return albumlist
    }
    
    // TODO: why does this require market query
    static func artistTopTracks(
        artistID: String,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.ID] {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/top-tracks",
            queryItems: [URLQueryItem(name: "market", value: "US")]
        )
        let topTracks: Spotify.Artist.TopTracks
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        topTracks = try JSONDecoder().decode(Spotify.Artist.TopTracks.self, from: data)
        return topTracks.tracks.map({ $0.id })
    }
    
    static func search(
        query: String,
        userManager: Musubi.UserManager
    ) async throws -> Spotify.SearchResults {
        var request = try SpotifyRequests.createRequest(
            type: HTTPMethod.GET,
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "artist,album,playlist,track"),
                URLQueryItem(name: "limit", value: "5")
            ]
        )
        let data = try await userManager.makeAuthdSpotifyRequest(request: &request)
        return try JSONDecoder().decode(Spotify.SearchResults.self, from: data)
    }
}
