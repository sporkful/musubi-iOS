// StaticArtistPage.swift

import SwiftUI

struct StaticArtistPage: View {
    let artistMetadata: Spotify.ArtistMetadata
    
    var body: some View {
        Text("Artist \(artistMetadata.name)")
    }
}

//#Preview {
//    StaticArtistPage()
//}
