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
        let album: AlbumMetadata?
        let artists: [ArtistMetadata]
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
    
    // MARK: Artist info
    
    struct ArtistMetadata: SpotifyIdentifiable, SpotifyNameable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        let name: String
        let images: [Spotify.Image]?
    }
    
    struct ArtistTopTracks: SpotifyViewModel {
        let tracks: [AudioTrack]
    }
    
    struct ArtistAlbumPage: SpotifyListPage {
        let items: [AlbumMetadata]
        let next: String?
    }
    
    // MARK: Album info
    
    struct AlbumMetadata: SpotifyIdentifiable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        let album_type: String
        let images: [Spotify.Image]?
        let name: String
        let release_date: String
        let artists: [ArtistMetadata]
//        let copyrights: Copyrights
//        let label: String
        
        struct Copyrights: Codable, Hashable {
            let text: String
            let type: String
        }
    }
    
    struct AlbumAudioTrackPage: SpotifyListPage {
        let items: [AudioTrack]
        let next: String?
    }
    
    // MARK: Playlist info
    
    struct PlaylistMetadata: SpotifyIdentifiable, SpotifyModelCardable, Hashable {
        let id: Spotify.ID
        private let description: String
//        let followers: Followers
        let images: [Spotify.Image]?
        let name: String
        let owner: OtherUser
        let snapshot_id: String
        
        var descriptionTextFromHTML: String {
            description.decodingHTMLEntities()
        }
        
        struct Followers: Codable, Hashable {
            let total: Int
        }
    }
    
    struct PlaylistAudioTrackPage: SpotifyListPage {
        let items: [PlaylistAudioTrackItem]
        let next: String?
    }
    
    struct PlaylistAudioTrackItem: SpotifyIdentifiable {
        let track: AudioTrack
        
        // TODO: make sure this computed property doesn't mess up JSON decoding
        var id: Spotify.ID { track.id }
    }
}

extension Array where Element == Spotify.AudioTrack {
    static func from(playlistTrackItems: [Spotify.PlaylistAudioTrackItem]) -> Self {
        return playlistTrackItems.map { item in item.track }
    }
}

// TODO: metadata returned from search query is stripped, so just pull bare display info then expand when user clicks
extension Spotify {
    struct SearchResults: SpotifyViewModel {
        var albums: Albums
        var artists: Artists
        var tracks: AudioTracks
        var playlists: Playlists
        
        struct Albums: SpotifyViewModel {
            let items: [AlbumMetadata]
        }
        
        struct Artists: SpotifyViewModel {
            let items: [ArtistMetadata]
        }
        
        struct AudioTracks: SpotifyViewModel {
            let items: [AudioTrack]
        }
        
        struct Playlists: SpotifyViewModel {
            let items: [PlaylistMetadata]
        }
        
        static let blank = Self(
            albums: Albums(items: []),
            artists: Artists(items: []),
            tracks: AudioTracks(items: []),
            playlists: Playlists(items: [])
        )
    }
}
