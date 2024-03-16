// StaticArtistPage.swift

import SwiftUI

struct StaticArtistPage: View {
    let artist: Spotify.Artist
    
    var body: some View {
        Text("Artist \(artist.name)")
    }
}

//#Preview {
//    StaticArtistPage()
//}
