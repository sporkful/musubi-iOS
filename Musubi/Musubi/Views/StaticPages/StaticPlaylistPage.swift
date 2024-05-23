// StaticPlaylistPage.swift

import SwiftUI

struct StaticPlaylistPage: View {
    @Environment(Musubi.User.self) private var currentUser
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @Binding var navigationPath: NavigationPath
    
    let playlistMetadata: Spotify.PlaylistMetadata
    
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
        .alert("Musubi - failed to create local clone", isPresented: $showAlertCloneError, actions: {})
    }
    
    // TODO: handle if already cloned
    // TODO: automatically (switch tabs and) open clone upon success
    // TODO: also pop this off navstack upon success so users don't get confused?
    private func initOrClone() {
        Task { @MainActor in
            homeViewCoordinator.disableUI = true
            defer { homeViewCoordinator.disableUI = false }
            
            homeViewCoordinator.myReposNavPath.removeLast(homeViewCoordinator.myReposNavPath.count)
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            homeViewCoordinator.openTab = .myRepos
            
            if !self.currentUser.localClonesIndex.contains(where: { $0.handle == self.associatedRepositoryHandle }) {
                do {
                    try await self.currentUser.initOrClone(
                        repositoryHandle: Musubi.RepositoryHandle(
                            userID: currentUser.id,
                            playlistID: playlistMetadata.id
                        )
                    )
                    try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                } catch {
                    print("[Musubi::StaticPlaylistPage] initOrClone error")
                    print(error.localizedDescription)
                    showAlertCloneError = true
                    return
                }
            }
            
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            homeViewCoordinator.myReposNavPath.append(self.associatedRepositoryHandle)
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
        }
    }
    
    // TODO: impl
    private func forkOrClone() {
        
    }
}

//#Preview {
//    StaticPlaylistPage()
//}
