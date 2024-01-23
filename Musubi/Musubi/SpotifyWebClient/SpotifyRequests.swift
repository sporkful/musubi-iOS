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
    static func fetchAudioTrack(audioTrackID: Spotify.Model.ID, userManager: Musubi.UserManager)
        async throws -> SpotifyAPIModel.AudioTrack
    {
        var request = try newURLRequest(type: HTTPMethod.GET,
                                        path: "/tracks/" + audioTrackID)
        let data = try await spotifyUserManager.makeAuthenticatedRequest(request: &request)
        return try JSONDecoder().decode(SpotifyAPIModel.AudioTrack.self, from: data)
    }
    
    static func fetchArtist(artistID: Spotify.Model.ID, userManager: Musubi.UserManager)
        async throws -> SpotifyAPIModel.Artist
    {
        var request = try newURLRequest(type: HTTPMethod.GET,
                                        path: "/artists/" + artistID)
        let data = try await spotifyUserManager.makeAuthenticatedRequest(request: &request)
        return try JSONDecoder().decode(SpotifyAPIModel.Artist.self, from: data)
    }
    
    static func fetchAlbum(albumID: Spotify.Model.ID, userManager: Musubi.UserManager)
        async throws -> SpotifyAPIModel.Album
    {
        var request = try newURLRequest(type: HTTPMethod.GET,
                                        path: "/albums/" + albumID)
        let data = try await spotifyUserManager.makeAuthenticatedRequest(request: &request)
        return try JSONDecoder().decode(SpotifyAPIModel.Album.self, from: data)
    }
    
    static func fetchPlaylist(playlistID: Spotify.Model.ID, userManager: Musubi.UserManager)
        async throws -> SpotifyAPIModel.Playlist
    {
        var request = try newURLRequest(type: HTTPMethod.GET,
                                        path: "/playlists/" + playlistID)
        let data = try await spotifyUserManager.makeAuthenticatedRequest(request: &request)
        return try JSONDecoder().decode(SpotifyAPIModel.Playlist.self, from: data)
    }
}
