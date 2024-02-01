// AlbumDetailView.swift

import SwiftUI

struct AlbumDetailView: View {
    let album: Spotify.Model.Album
    
    var body: some View {
        Text("Album")
        Text(album.name)
    }
}

//#Preview {
//    AlbumDetailView()
//}
