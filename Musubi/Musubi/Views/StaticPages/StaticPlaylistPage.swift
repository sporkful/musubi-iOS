// StaticPlaylistPage.swift

import SwiftUI

struct StaticPlaylistPage: View {
    @Environment(Musubi.User.self) private var currentUser
    
    @Binding var navigationPath: NavigationPath
    
    let playlistMetadata: Spotify.PlaylistMetadata
    
    @State private var isViewDisabled = false
    @State private var showAlertCloneError = false
    
    private var associatedRepositoryHandle: Musubi.RepositoryHandle {
        Musubi.RepositoryHandle(userID: playlistMetadata.owner.id, playlistID: playlistMetadata.id)
    }
    
    private var cloningToolbarItem: AudioTrackListPage.CustomToolbarItem {
        if playlistMetadata.owner.id == currentUser.id {
            return AudioTrackListPage.CustomToolbarItem(
                title: "Get your Musubi repository",
                sfSymbolName: "square.and.arrow.down.on.square",
                action: initOrClone
            )
        } else {
            return AudioTrackListPage.CustomToolbarItem(
                title: "Get your personal Musubi fork",
                sfSymbolName: "arrow.triangle.branch",
                action: forkOrClone
            )
        }
    }
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            audioTrackList: Musubi.ViewModel.AudioTrackList(playlistMetadata: playlistMetadata),
            showAudioTrackThumbnails: true,
            customToolbarAdditionalItems: [cloningToolbarItem]
        )
        .disabled(isViewDisabled)
        .alert("Musubi - failed to create local clone", isPresented: $showAlertCloneError, actions: {})
    }
    
    // TODO: handle if already cloned
    // TODO: automatically (switch tabs and) open clone upon success
    // TODO: also pop this off navstack upon success so users don't get confused?
    private func initOrClone() {
        isViewDisabled = true
        Task {
            do {
//                if self.currentUser.localClonesIndex.contains(where: { $0.handle == self.associatedRepositoryHandle }) {
//                    return []
//                }
                try await self.currentUser.initOrClone(
                    repositoryHandle: Musubi.RepositoryHandle(
                        userID: currentUser.id,
                        playlistID: playlistMetadata.id
                    )
                )
            } catch {
                print("[Musubi::StaticPlaylistPage] initOrClone error")
                print(error.localizedDescription)
                showAlertCloneError = true
            }
            isViewDisabled = false
        }
    }
    
    // TODO: impl
    private func forkOrClone() {
        
    }
}

//#Preview {
//    StaticPlaylistPage()
//}
