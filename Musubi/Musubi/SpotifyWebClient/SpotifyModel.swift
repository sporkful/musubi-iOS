// SpotifyModel.swift

import Foundation

extension Spotify {
    typealias ID = String
    
    struct AuthResponse: Codable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String
        let token_type: String
    }
    
    struct CurrentUser: Codable {
        let country: String
        let display_name: String
        let explicit_content: [String: Bool]
        let external_urls: [String: String]
        let id: String
        let images: [SpotifyImage]?
        let product: String
    }
    
    struct OtherUser: Codable {
        let display_name: String
        let external_urls: [String: String]
        let id: String
        let images: [SpotifyImage]?
    }
    
    struct SpotifyImage: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }
}

// namespaces
struct Spotify {
    private init() { }
    
    struct Constants {
        private init() { }
    }
}
