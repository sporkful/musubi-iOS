// AudioTrackListCell.swift

import SwiftUI

// TODO: rename to Playable...?

struct AudioTrackListCell: View {
    let isNavigable: Bool
    @Binding var navigationPath: NavigationPath
    
    let audioTrackListElement: Musubi.ViewModel.AudioTrackList.UniquifiedElement
    
    let showThumbnail: Bool
    let customTextStyle: ListCell.CustomTextStyle
    
    @State private var audioTrack: Spotify.AudioTrack? = nil
    
    @State private var showSheetAddToSelectableClones = false
    
    @State private var showAlertUnsupportedAction = false
    
    var body: some View {
        HStack {
            if let audioTrack = self.audioTrack {
                ListCellWrapper(
                    item: audioTrack,
                    showThumbnail: showThumbnail,
                    customTextStyle: customTextStyle
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    // TODO: implement playback through audioTrackListElement.parent
                    print("playing \(audioTrack.name)")
                }
            } else {
                ListCell(
                    title: "(Loading track...)",
                    caption: "(ID: \(self.audioTrackListElement.audioTrackID))",
                    thumbnailURLString: nil,
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
                    audioTrackList: Musubi.ViewModel.AudioTrackList(audioTrack: audioTrack),
                    showSheet: $showSheetAddToSelectableClones
                )
            }
            // TODO: handle else case better?
        }
        .alert("Musubi - unsupported action", isPresented: $showAlertUnsupportedAction, actions: {})
        .onChange(of: self.audioTrack, initial: true) { _, audioTrack in
            if audioTrack == nil {
                Task { @MainActor in
                    self.audioTrack = await self.audioTrackListElement.audioTrack
                }
            }
        }
    }
}

//#Preview {
//    AudioTrackListCell()
//}
