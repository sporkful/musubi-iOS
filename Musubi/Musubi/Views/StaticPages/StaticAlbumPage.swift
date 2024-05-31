// StaticAlbumPage.swift

import SwiftUI

struct StaticAlbumPage: View {
    @Binding var navigationPath: NavigationPath
    
    @State var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            audioTrackList: audioTrackList,
            showAudioTrackThumbnails: false,
            customToolbarAdditionalItems: []
        )
    }
}

//#Preview {
//    StaticAlbumPage()
//}
