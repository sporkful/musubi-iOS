// MusubiViewModel.swift

import Foundation

extension Musubi.ViewModel {
    typealias Repository = Musubi.Model.Repository
    typealias Commit = Musubi.Model.Commit
    
    struct Playlist: Identifiable {
        let id: Spotify.Model.ID
        var name: String
        var description: String
        var items: [Item]
        
        struct Item: Hashable {
            // The sole purpose of `index` is to give each Item a temporary but stable identifier
            // for presentation as an editable SwiftUI List. This is necessary since there may be
            // repeated audio tracks within a playlist.
            //
            // NOTE: `index` is intended to only be stable for the (temporary) lifetime of the
            // SwiftUI List it backs.
            //
            // NOTE: `index` is not dynamically updated after initial materialization.
            // In particular, if the SwiftUI List it backs is reordered, `index` might no longer be
            // the logically correct index of the item in the playlist.
            
            let index: Int
            let audioTrackID: Spotify.Model.ID
        }
        
        static func from(playlist: Musubi.Model.Playlist) -> Self {
            Self(
                id: playlist.id,
                name: playlist.name,
                description: playlist.description,
                items: playlist.items.enumerated().map( { item in
                    Item(index: item.offset, audioTrackID: item.element)
                })
            )
        }
        
        func into() -> Musubi.Model.Playlist {
            Musubi.Model.Playlist(
                id: self.id,
                name: self.name,
                description: self.description,
                items: self.items.map({ item in item.audioTrackID })
            )
        }
    }
}
