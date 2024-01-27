// AudioTrackDetailView.swift

import SwiftUI

struct AudioTrackDetailView: View {
    let audioTrack: Spotify.Model.AudioTrack
    
    var body: some View {
        Text(audioTrack.name)
    }
}

//#Preview {
//    AudioTrackDetailView()
//}
