// SpotifyRequests.swift

import Foundation

extension SpotifyWebClient {
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
}
