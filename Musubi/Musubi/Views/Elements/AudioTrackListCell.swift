// AudioTrackListCell.swift

import SwiftUI

// TODO: playback ability
//  - change audioTrack to ViewModel.UIDableAudioTrack and add context: ViewModel.AudioTrackList

struct AudioTrackListCell: View {
    let isNavigable: Bool
    @Binding var navigationPath: NavigationPath
    
    let audioTrackListElement: Musubi.ViewModel.AudioTrackList.UniquifiedElement
    
    let showThumbnail: Bool
    var customTextStyle: ListCell.CustomTextStyle = .defaultStyle  // TODO: turn into custom view modifier?
    
    @State private var audioTrack: Spotify.AudioTrack? = nil
    
    @State private var showSheetAddToSelectableClones = false
    
    @State private var showAlertUnsupportedAction = false
    
    var body: some View {
        HStack {
            if let audioTrack = self.audioTrack {
            ListCell(item: audioTrack, showThumbnail: showThumbnail, customTextStyle: customTextStyle)
                .contentShape(Rectangle())
                .onTapGesture {
                    // TODO: implement playback through audioTrackListElement.context
                    print("playing \(audioTrack.name)")
                }
            } else {
                ListCell(
                    title: "(Unable to load track metadata)",
                    caption: "ID: \(self.audioTrackListElement.audioTrackID)",
                    thumbnailURL: nil,
                    showThumbnail: showThumbnail,
                    customTextStyle: customTextStyle
                )
            }
            if isNavigable {
            Menu {
                Button {
                    showSheetAddToSelectableClones = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add track to")
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
                // TODO: apply this pattern in rest of views (condition outside button instead of inside action)
                if let album = self.audioTrack?.album {
                Button {
                    navigationPath.append(album)
                } label: {
                    HStack {
                        Image(systemName: "smallcircle.circle")
                        Text("View album")
                    }
                }
                }
                if let primaryArtist = self.audioTrack?.artists.first {
                Button {
                    navigationPath.append(primaryArtist)
                } label: {
                    HStack {
                        Image(systemName: "person")
                        Text("View artist")
                    }
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
                    .font(.system(size: Musubi.UI.MENU_SYMBOL_SIZE))
                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                    .contentShape(Rectangle())
            }
            }
        }
        .sheet(isPresented: $showSheetAddToSelectableClones) {
            if let audioTrack = self.audioTrack {
                AddToSelectableLocalClonesSheet(
                    audioTrackList: try! Musubi.ViewModel.AudioTrackList(audioTracks: [audioTrack]),
                    showSheet: $showSheetAddToSelectableClones
                )
            } else {
                // TODO: handle this case better
                AddToSelectableLocalClonesSheet(
                    audioTrackList: try! Musubi.ViewModel.AudioTrackList(audioTracks: []),
                    showSheet: $showSheetAddToSelectableClones
                )
            }
        }
        .alert("Musubi - unsupported action", isPresented: $showAlertUnsupportedAction, actions: {})
        .task {
            self.audioTrack = await self.audioTrackListElement.audioTrack
        }
    }
}

//#Preview {
//    AudioTrackListCell()
//}
