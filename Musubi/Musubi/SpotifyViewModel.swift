// SpotifyViewModel.swift

import Foundation

// namespaces
struct Spotify {
    private init() { }
}

protocol SpotifyViewModel: Codable { }

protocol SpotifyIdentifiable: SpotifyViewModel, Identifiable {
    var id: Spotify.ID { get }
}

protocol SpotifyNameable: SpotifyViewModel {
    var name: String { get }
}

protocol SpotifyListPage: SpotifyViewModel {
    associatedtype ItemType: SpotifyIdentifiable
    
    var items: [ItemType] { get }
    var next: String? { get }
}

protocol SpotifyModelCardable: SpotifyViewModel {
    var name: String { get }
    var images: [Spotify.Image]? { get }
    
    // TODO: playback?
}

extension Spotify {
    typealias ID = String
    
    struct Image: SpotifyViewModel, Hashable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    struct LoggedInUser: SpotifyIdentifiable, SpotifyNameable {
//        let country: String
        let display_name: String
//        let explicit_content: [String: Bool]
//        let external_urls: [String: String]
        let id: Spotify.ID
//        let images: [Spotify.Image]?
//        let product: String
        
        var name: String { display_name }
    }
    
    struct OtherUser: SpotifyIdentifiable, SpotifyNameable, Hashable {
        let display_name: String
        let external_urls: [String: String]
        let id: Spotify.ID
        let images: [Spotify.Image]?
        
        var name: String { display_name }
    }
    
    struct AudioTrack: SpotifyIdentifiable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        let album: Album?
        let artists: [Artist]
        let available_markets: [String]?
        let disc_number: Int
        let duration_ms: Int
        let explicit: Bool
        let external_urls: [String: String]
        let name: String
        let preview_url: String?
        
        // TODO: make sure this computed property doesn't mess up JSON decoding
        var images: [Spotify.Image]? { album?.images }
    }
    
    struct Artist: SpotifyIdentifiable, SpotifyNameable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        let name: String
        let images: [Spotify.Image]?
        
        struct TopTracks: SpotifyViewModel {
            let tracks: [AudioTrack]
        }
        
        struct AlbumListPage: SpotifyListPage {
            let items: [Album]
            let next: String?
        }
    }
    
    struct Album: SpotifyIdentifiable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        let name: String
        let album_type: String
        let images: [Spotify.Image]?
        let release_date: String
        let uri: String
        let artists: [Artist]
        
        struct AudioTrackListPage: SpotifyListPage {
            let items: [AudioTrack]
            let next: String?
        }
    }
    
    struct Playlist: SpotifyIdentifiable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        let description: String
        let external_urls: [String: String]
        let images: [Spotify.Image]?
        let name: String
        let owner: OtherUser
        let snapshot_id: String
        let uri: String
        
        struct AudioTrackListPage: SpotifyListPage {
            let items: [AudioTrackItem]
            let next: String?
        }
        
        struct AudioTrackItem: SpotifyIdentifiable {
            let track: AudioTrack
            
            // TODO: make sure this computed property doesn't mess up JSON decoding
            var id: Spotify.ID { track.id }
        }
    }
}

extension Array where Element == Spotify.AudioTrack {
    static func from(playlistTrackItems: [Spotify.Playlist.AudioTrackItem]) -> Self {
        return playlistTrackItems.map { item in item.track }
    }
}

extension Spotify {
    struct SearchResults: SpotifyViewModel {
        var albums: Albums
        var artists: Artists
        var tracks: AudioTracks
        var playlists: Playlists
        
        struct Albums: SpotifyViewModel {
            let items: [Album]
        }
        
        struct Artists: SpotifyViewModel {
            let items: [Artist]
        }
        
        struct AudioTracks: SpotifyViewModel {
            let items: [AudioTrack]
        }
        
        struct Playlists: SpotifyViewModel {
            let items: [Playlist]
        }
        
        static func blank() -> Self {
            return Self(
                albums: Albums(items: []),
                artists: Artists(items: []),
                tracks: AudioTracks(items: []),
                playlists: Playlists(items: [])
            )
        }
    }
}
