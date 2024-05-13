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

protocol SpotifyPreviewable: SpotifyViewModel {
    var name: String { get }
    var images: [Spotify.Image]? { get }
}

protocol SpotifyNavigable: SpotifyViewModel, Hashable {}

protocol SpotifyListPage: SpotifyViewModel {
    associatedtype Item: SpotifyViewModel
    
    var items: [Item] { get }
    var next: String? { get }
}

extension Spotify {
    typealias ID = String
    
    struct Image: SpotifyViewModel {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    struct LoggedInUser: SpotifyIdentifiable, SpotifyPreviewable {
        let country: String
        let display_name: String?
        let explicit_content: [String: Bool]
//        let external_urls: [String: String]
        let id: Spotify.ID
        let images: [Spotify.Image]?
        let product: String
        
        var name: String { display_name ?? id }
    }
    
    struct OtherUser: SpotifyIdentifiable, SpotifyPreviewable {
        let display_name: String?
        let external_urls: [String: String]
        let id: Spotify.ID
        let images: [Spotify.Image]?
        
        var name: String { display_name ?? id }
    }
    
    struct AudioTrack: SpotifyIdentifiable, SpotifyPreviewable, SpotifyNavigable {
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
    
    struct ArtistMetadata: SpotifyIdentifiable, SpotifyPreviewable, SpotifyNavigable {
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
    
    struct AlbumMetadata: SpotifyIdentifiable, SpotifyPreviewable, SpotifyNavigable {
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
    
    struct PlaylistMetadata: SpotifyIdentifiable, SpotifyPreviewable, SpotifyNavigable {
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

extension Spotify.AudioTrack {
    init(audioTrack: Spotify.AudioTrack, withAlbumMetadata: Spotify.AlbumMetadata) {
        self.init(
            id: audioTrack.id,
            album: withAlbumMetadata,
            artists: audioTrack.artists,
            available_markets: audioTrack.available_markets,
            disc_number: audioTrack.disc_number,
            duration_ms: audioTrack.duration_ms,
            explicit: audioTrack.explicit,
            external_urls: audioTrack.external_urls,
            name: audioTrack.name,
            preview_url: audioTrack.preview_url
        )
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

// components of SpotifyNavigable types
extension Spotify.Image: Hashable {}
extension Spotify.OtherUser: Hashable {}
