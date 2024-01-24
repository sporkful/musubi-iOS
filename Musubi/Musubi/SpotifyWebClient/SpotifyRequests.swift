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
    
    private static func makeAuthenticatedRequest<T: SpotifyModel>(
        request: inout URLRequest,
        userManager: Musubi.UserManager
    ) async throws -> T {
        let data = try await Spotify.Auth.makeAuthenticatedRequest(
            request: &request,
            userManager: userManager
        )
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private static func multipageList<T: SpotifyModelPage>(
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
    ) async throws -> [Spotify.Model.ID] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/albums/" + albumID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Model.Album.AudioTrackPage
        firstPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        return try await multipageList(firstPage: firstPage, userManager: userManager)
    }
    
    static func playlistTracklist(
        playlistID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.ID] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/playlists/" + playlistID + "/tracks/",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Model.Playlist.AudioTrackPage
        firstPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        return try await multipageList(firstPage: firstPage, userManager: userManager)
    }
    
    static func artistAlbums(
        artistID: Spotify.Model.ID,
        userManager: Musubi.UserManager
    ) async throws -> [Spotify.Model.ID] {
        var request = try Requests.createRequest(
            type: HTTPMethod.GET,
            path: "/artists/" + artistID + "/albums",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        let firstPage: Spotify.Model.Artist.AlbumPage
        firstPage = try await makeAuthenticatedRequest(request: &request, userManager: userManager)
        return try await multipageList(firstPage: firstPage, userManager: userManager)
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
}
