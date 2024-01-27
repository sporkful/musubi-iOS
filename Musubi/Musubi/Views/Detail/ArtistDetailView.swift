// ArtistDetailView.swift

import SwiftUI

struct ArtistDetailView: View {
    let artist: Spotify.Model.Artist
    
    var body: some View {
        Text(artist.name)
    }
}

//#Preview {
//    ArtistDetailView()
//}
