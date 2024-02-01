// PlaylistDetailView.swift

import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Spotify.Model.Playlist
    
    var body: some View {
        Text("Playlist")
        Text(playlist.name)
    }
}

//#Preview {
//    PlaylistDetailView()
//}
