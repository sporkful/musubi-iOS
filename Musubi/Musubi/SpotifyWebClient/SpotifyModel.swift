// SpotifyModel.swift

import Foundation

protocol SpotifyModel: Codable { }

protocol SpotifyModelIdentifiable: SpotifyModel, Identifiable {
    var id: Spotify.Model.ID { get }
}

protocol SpotifyModelPage: SpotifyModel {
    associatedtype ItemType: SpotifyModelIdentifiable
    
    var items: [ItemType] { get }
    var next: String? { get }
}

extension Spotify.Model {
    typealias ID = String
    
    struct LoggedInUser: SpotifyModelIdentifiable {
//        let country: String
        let display_name: String
//        let explicit_content: [String: Bool]
//        let external_urls: [String: String]
        let id: Spotify.Model.ID
//        let images: [SpotifyImage]?
//        let product: String
    }
    
    struct OtherUser: SpotifyModelIdentifiable {
        let display_name: String
        let external_urls: [String: String]
        let id: Spotify.Model.ID
        let images: [SpotifyImage]?
    }
    
    struct SpotifyImage: SpotifyModel {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    struct AudioTrack: SpotifyModelIdentifiable {
        let id: Spotify.Model.ID
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
    
    struct Artist: SpotifyModelIdentifiable {
        let id: Spotify.Model.ID
        let name: String
        let images: [SpotifyImage]?
        
        struct TopTracks: SpotifyModel {
            let tracks: [AudioTrack]
        }
        
        struct AlbumPage: SpotifyModelPage {
            let items: [Album]
            let next: String?
        }
    }
    
    struct Album: SpotifyModelIdentifiable {
        let id: Spotify.Model.ID
        let name: String
        let album_type: String
        let images: [SpotifyImage]?
        let release_date: String
        let uri: String
        let artists: [Artist]
        
        struct AudioTrackPage: SpotifyModelPage {
            let items: [AudioTrack]
            let next: String?
        }
    }
    
    struct Playlist: SpotifyModelIdentifiable {
        let id: Spotify.Model.ID
        let description: String
        let external_urls: [String: String]
        let images: [SpotifyImage]?
        let name: String
        let owner: OtherUser
        let snapshot_id: String
        let uri: String
        
        struct AudioTrackPage: SpotifyModelPage {
            let items: [AudioTrackItem]
            let next: String?
        }
        
        struct AudioTrackItem: SpotifyModelIdentifiable {
            let track: AudioTrack
            
            // TODO: make sure this computed property doesn't mess up JSON decoding
            var id: Spotify.Model.ID { track.id }
        }
    }
    
    struct SearchResults: SpotifyModel {
        var albums: Albums
        var artists: Artists
        var tracks: AudioTracks
        var playlists: Playlists
        
        struct Albums: SpotifyModel {
            let items: [Album]
        }
        
        struct Artists: SpotifyModel {
            let items: [Artist]
        }
        
        struct AudioTracks: SpotifyModel {
            let items: [AudioTrack]
        }
        
        struct Playlists: SpotifyModel {
            let items: [Playlist]
        }
    }
}
