// PlaylistDetailView.swift

import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Spotify.Model.Playlist
    
    var body: some View {
        Text(playlist.name)
    }
}

//#Preview {
//    PlaylistDetailView()
//}
