// AudioTrackListCell.swift

import SwiftUI

// TODO: fix flashing that occurs when containing view is disabled
// TODO: rename to Playable...?

struct AudioTrackListCell: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    // TODO: better way to do this?
    let isNavigable: Bool
    @Binding var navigationPath: NavigationPath
    
    let audioTrackListElement: Musubi.ViewModel.AudioTrackList.UniquifiedElement
    
    let showThumbnail: Bool
    let customTextStyle: ListCell.CustomTextStyle
    
    @State private var audioTrack: Spotify.AudioTrack? = nil
    
    @State private var showSheetAddToSelectableClones = false
    
    @State private var showAlertErrorStartPlayback = false
    @State private var showAlertUnsupportedAction = false
    
    var body: some View {
        HStack {
            if let audioTrack = self.audioTrack {
                ListCellWrapper(
                    item: audioTrack,
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
                if let album = self.audioTrack?.album,
                   album != self.audioTrackListElement.parent?.context as? Spotify.AlbumMetadata
                {
                Button {
                    navigationPath.append(album)
                } label: {
                    HStack {
                        Image(systemName: "smallcircle.circle")
                        Text("View album")
                    }
                }
                }
                if let primaryArtist = self.audioTrack?.artists.first,
                   primaryArtist != self.audioTrackListElement.parent?.context as? Spotify.ArtistMetadata
                {
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
//                    .font(.system(size: Musubi.UI.MENU_SYMBOL_SIZE))
                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                    .contentShape(Rectangle())
            }
            }
        }
        .sheet(isPresented: $showSheetAddToSelectableClones) {
            if let audioTrack = self.audioTrack {
                AddToSelectableLocalClonesSheet(
                    showSheet: $showSheetAddToSelectableClones,
                    audioTrackList: Musubi.ViewModel.AudioTrackList(audioTrack: audioTrack)
                )
            }
            // TODO: handle else case better?
        }
        .alert(
            "Error when starting playback",
            isPresented: $showAlertErrorStartPlayback,
            actions: {},
            message: {
                Text(SpotifyPlaybackManager.PLAY_ERROR_MESSAGE)
            }
        )
        .alert("Action not supported yet", isPresented: $showAlertUnsupportedAction, actions: {})
        .onChange(of: self.audioTrack, initial: true) { _, audioTrack in
            if !hasInitialLoaded || audioTrack == nil {
                Task { @MainActor in
                    self.audioTrack = await self.audioTrackListElement.audioTrack
                    self.hasInitialLoaded = true
                }
            }
        }
    }
    
    @State private var hasInitialLoaded = false
}

//#Preview {
//    AudioTrackListCell()
//}
