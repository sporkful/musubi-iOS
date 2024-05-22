// StaticAlbumPage.swift

import SwiftUI

struct StaticAlbumPage: View {
    @Binding var navigationPath: NavigationPath
    
    let albumMetadata: Spotify.AlbumMetadata
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            audioTrackList: Musubi.ViewModel.AudioTrackList(albumMetadata: albumMetadata),
            showAudioTrackThumbnails: false,
            customToolbarAdditionalItems: []
        )
    }
}

//#Preview {
//    StaticAlbumPage()
//}
