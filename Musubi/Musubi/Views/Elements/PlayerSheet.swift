// PlayerSheet.swift

import SwiftUI

struct PlayerSheet: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    @Binding var showSheet: Bool
    
    var body: some View {
        ScrollView {
            if let currentTrack = spotifyPlaybackManager.currentTrack {
                VStack {
                    HStack {
                        Button(
                            action: { showSheet = false },
                            label: {
                                Image(systemName: "chevron.down")
                            }
                        )
                        Spacer()
                        VStack(alignment: .center) {
                            Text(currentTrack.parent?.context.type ?? "")
                                .font(.caption)
                                .lineLimit(1, reservesSpace: true)
                            Text(currentTrack.parent?.context.name ?? "")
                                .font(.subheadline)
                                .bold()
                                .lineLimit(2, reservesSpace: true)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                        SingleAudioTrackMenu(
                            audioTrack: currentTrack,
                            showParentSheet: $showSheet
                        )
                    }
                    .padding()
                }
            } else {
                Text("Something went wrong, please try again.")
            }
        }
        .interactiveDismissDisabled(false)
    }
}

//#Preview {
//    PlayerSheet()
//}
