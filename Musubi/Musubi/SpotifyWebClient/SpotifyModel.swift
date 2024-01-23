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
    
    struct AudioTrack: Codable, Identifiable {
        let id: String
        let album: Album?
        let artists: [Artist]
        let available_markets: [String]?
        let disc_number: Int
        let duration_ms: Int
        let explicit: Bool
        let external_urls: [String: String]
        let name: String
        let preview_url: String?
    }
    
    struct Artist: Codable, Identifiable {
        let id: String
        let name: String
        let images: [SpotifyImage]?
        
        struct TopTracks: Codable {
            let tracks: [AudioTrack]
        }
        
        struct AlbumPage: Codable {
            let items: [Album]
            let next: String?
        }
    }
    
    struct Album: Codable, Identifiable {
        let id: String
        let name: String
        let album_type: String
        let images: [SpotifyImage]?
        let release_date: String
        let uri: String
        let artists: [Artist]
        
        struct AudioTrackPage: Codable {
            let items: [AudioTrack]
            let next: String?
        }
    }
    
    struct Playlist: Codable, Identifiable {
        let id: String
        let description: String
        let external_urls: [String: String]
        let images: [SpotifyImage]?
        let name: String
        let owner: OtherUser
        let snapshot_id: String
        let uri: String
        
        struct AudioTrackPage: Codable {
            let items: [AudioTrackItem]
            let next: String?
        }
        
        struct AudioTrackItem: Codable {
            let track: AudioTrack
        }
    }
    
    struct SearchResults: Codable {
        var albums: Albums
        var artists: Artists
        var tracks: AudioTracks
        var playlists: Playlists
        
        struct Albums: Codable {
            let items: [Album]
        }
        
        struct Artists: Codable {
            let items: [Artist]
        }
        
        struct AudioTracks: Codable {
            let items: [AudioTrack]
        }
        
        struct Playlists: Codable {
            let items: [Playlist]
        }
    }
}
