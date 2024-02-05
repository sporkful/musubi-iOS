// PlaylistStaticPageView.swift

import SwiftUI

struct PlaylistStaticPageView: View {
    let playlist: Spotify.Model.Playlist
    
    var body: some View {
        Text("Playlist")
        Text(playlist.name)
    }
}

//#Preview {
//    PlaylistStaticPageView()
//}
