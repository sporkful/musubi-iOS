// AudioTrackListCell.swift

import SwiftUI

// TODO: fix flashing that occurs when containing view is disabled
// TODO: rename to Playable...?

struct AudioTrackListCell: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    let audioTrackListElement: Musubi.ViewModel.AudioTrackList.UniquifiedElement
    
    let showMenu: Bool
    let showThumbnail: Bool
    let customTextStyle: ListCell.CustomTextStyle
    
    @State private var showAlertErrorStartPlayback = false
    @State private var showAlertUnsupportedAction = false
    
    var body: some View {
        HStack {
            ListCellWrapper(
                item: audioTrackListElement.audioTrack,
                showThumbnail: showThumbnail,
                customTextStyle: customTextStyle,
                isActive: spotifyPlaybackManager.currentTrack == audioTrackListElement,
                isPlaying: spotifyPlaybackManager.isPlaying
            )
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    do {
                        try await spotifyPlaybackManager.play(audioTrackListElement: self.audioTrackListElement)
                    } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                        showAlertErrorStartPlayback = true
                    } catch {
                        // TODO: handle
                        print(error)
                    }
                }
            }
            if showMenu {
                SingleAudioTrackMenu(
                    audioTrackListElement: audioTrackListElement,
                    showParentSheet: Binding.constant(false)
                )
            }
        }
        .alert(
            "Error when starting playback",
            isPresented: $showAlertErrorStartPlayback,
            actions: {},
            message: {
                Text(SpotifyPlaybackManager.PLAY_ERROR_MESSAGE)
            }
        )
    }
}

//#Preview {
//    AudioTrackListCell()
//}
