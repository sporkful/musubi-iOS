// SingleAudioTrackMenu.swift

import SwiftUI

// TODO: impl unsupported actions

struct SingleAudioTrackMenu: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    let audioTrackListElement: Musubi.ViewModel.AudioTrackList.UniquifiedElement
    
    // TODO: better way to do this?
    // if N/A, just pass in constant binding
    @Binding var showParentSheet: Bool
    
    @State private var showSheetAddToSelectableClones = false
    
    @State private var showAlertUnsupportedAction = false
    
    var body: some View {
        Menu {
            Button(
                action: { showSheetAddToSelectableClones = true },
                label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add track to")
                    }
                }
            )
            Button(
                action: { showAlertUnsupportedAction = true },
                label: {
                    HStack {
                        Image(systemName: "text.badge.plus")
                        Text("Add to queue")
                    }
                }
            )
            Button(
                action: { showAlertUnsupportedAction = true },
                label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
            )
            Button(
                action: { showAlertUnsupportedAction = true },
                label: {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Go to radio")
                    }
                }
            )
            if let album = self.audioTrackListElement.audioTrack.album
//               album != self.audioTrackListElement.parent?.context as? Spotify.AlbumMetadata
            {
                Button(
                    action: { openRelatedPage(spotifyNavigable: album) },
                    label: {
                        HStack {
                            Image(systemName: "smallcircle.circle")
                            Text("View album")
                        }
                    }
                )
            }
            if let primaryArtist = self.audioTrackListElement.audioTrack.artists.first
//               primaryArtist != self.audioTrackListElement.parent?.context as? Spotify.ArtistMetadata
            {
                Button(
                    action: { openRelatedPage(spotifyNavigable: primaryArtist) },
                    label: {
                        HStack {
                            Image(systemName: "person")
                            Text("View artist")
                        }
                    }
                )
            }
            Button(
                action: { showAlertUnsupportedAction = true },
                label: {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Song credits")
                    }
                }
            )
        } label: {
            Image(systemName: "ellipsis")
//                .font(.system(size: Musubi.UI.MENU_SYMBOL_SIZE))
                .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                .contentShape(Rectangle())
        }
        .sheet(isPresented: $showSheetAddToSelectableClones) {
            // Note decoupling with parent AudioTrackList is intentional here.
            AddToSelectableLocalClonesSheet(
                showSheet: $showSheetAddToSelectableClones,
                audioTrackList: Musubi.ViewModel.AudioTrackList(audioTrack: self.audioTrackListElement.audioTrack)
            )
        }
        .alert("Action not supported yet", isPresented: $showAlertUnsupportedAction, actions: {})
    }
    
    // TODO: better typing
    private func openRelatedPage(spotifyNavigable: any SpotifyNavigable) {
        Task { @MainActor in
            showParentSheet = false
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            if homeViewCoordinator.openTab != .spotifySearch {
                homeViewCoordinator.openTab = .spotifySearch
                try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            }
            homeViewCoordinator.spotifySearchNavPath.append(spotifyNavigable)
        }
    }
}

//#Preview {
//    SingleAudioTrackMenu()
//}
