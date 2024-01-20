// SpotifyModel.swift

import Foundation

extension Spotify.Model {
    typealias ID = String
    
    struct LoggedInUser: Codable, Identifiable {
//        let country: String
        let display_name: String
//        let explicit_content: [String: Bool]
//        let external_urls: [String: String]
        let id: String
//        let images: [SpotifyImage]?
//        let product: String
    }
    
    struct OtherUser: Codable, Identifiable {
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
