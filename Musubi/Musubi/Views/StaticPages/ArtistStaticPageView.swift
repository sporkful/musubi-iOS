// ArtistStaticPageView.swift

import SwiftUI

struct ArtistStaticPageView: View {
    let artist: Spotify.Model.Artist
    
    var body: some View {
        Text("Artist")
        Text(artist.name)
    }
}

//#Preview {
//    ArtistStaticPageView()
//}
