// AudioTrackListCell.swift

import SwiftUI

// TODO: playback ability

struct AudioTrackListCell: View {
    let isNavigable: Bool
    @Binding var navigationPath: NavigationPath
    
    let audioTrack: Spotify.AudioTrack
    let showThumbnail: Bool
    
    @State private var showAlertUnsupportedAction = false
    
    private let MENU_SYMBOL_SIZE = Musubi.UI.MENU_SYMBOL_SIZE
    
    var body: some View {
        HStack {
            ListCell(item: audioTrack, showThumbnail: showThumbnail)
                .contentShape(Rectangle())
                .onTapGesture {
                    // TODO: implement playback
                    print("playing \(audioTrack.name)")
                }
            if isNavigable {
            Menu {
                Button {
                    // TODO: impl
                    showAlertUnsupportedAction = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add to playlist")
                    }
                }
                Button {
                    // TODO: impl
                    showAlertUnsupportedAction = true
                } label: {
                    HStack {
                        Image(systemName: "text.badge.plus")
                        Text("Add to queue")
                    }
                }
                Button {
                    // TODO: impl
                    showAlertUnsupportedAction = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
                Button {
                    // TODO: impl
                    showAlertUnsupportedAction = true
                } label: {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Go to radio")
                    }
                }
                Button {
                    if let album = audioTrack.album {
                        navigationPath.append(album)
                    }
                } label: {
                    HStack {
                        Image(systemName: "smallcircle.circle")
                        Text("View album")
                    }
                }
                Button {
                    if let primaryArtist = audioTrack.artists.first {
                        navigationPath.append(primaryArtist)
                    }
                } label: {
                    HStack {
                        Image(systemName: "person")
                        Text("View artist")
                    }
                }
                Button {
                    // TODO: impl
                    showAlertUnsupportedAction = true
                } label: {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Song credits")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: MENU_SYMBOL_SIZE))
                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                    .contentShape(Rectangle())
            }
            }
        }
        .alert("Musubi - unsupported action", isPresented: $showAlertUnsupportedAction, actions: {})
    }
}

//#Preview {
//    AudioTrackListCell()
//}
