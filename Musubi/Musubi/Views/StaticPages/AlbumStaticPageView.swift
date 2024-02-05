// AlbumStaticPageView.swift

import SwiftUI

struct AlbumStaticPageView: View {
    let album: Spotify.Model.Album
    
    var body: some View {
        Text("Album")
        Text(album.name)
    }
}

//#Preview {
//    AlbumStaticPageView()
//}
