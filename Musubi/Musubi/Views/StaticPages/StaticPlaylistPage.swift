// StaticPlaylistPage.swift

import SwiftUI

struct StaticPlaylistPage: View {
    @Environment(Musubi.User.self) private var currentUser
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @Binding var navigationPath: NavigationPath
    
    @State var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    private var playlistMetadata: Spotify.PlaylistMetadata {
        audioTrackList.context as! Spotify.PlaylistMetadata
    }
    
    @State private var showAlertAlreadyCloned = false
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
            audioTrackList: audioTrackList,
            showAudioTrackThumbnails: true,
            customToolbarAdditionalItems: [
                (
                    // TODO: clean up (can't access localClonesIndex from computed prop)
                    !self.currentUser.localClonesIndex.contains(where: { $0.handle == self.associatedRepositoryHandle })
                        ? cloningToolbarItem
                        : AudioTrackListPage.CustomToolbarItem(
                            title: playlistMetadata.owner.id == currentUser.id
                                ? "Get your Musubi repository"
                                : "Get your personal Musubi fork",
                            sfSymbolName: playlistMetadata.owner.id == currentUser.id
                                ? "square.and.arrow.down.on.square"
                                : "arrow.triangle.branch",
                            action: { showAlertAlreadyCloned = true },
                            isDisabledVisually: true
                        )
                )
            ]
        )
        .alert(
            "Already in local repositories!",
            isPresented: $showAlertAlreadyCloned,
            actions: {
                Button("Cancel", action: {})
                Button("Open", action: openExistingClone).bold()
            },
            message: {
                Text("Would you like to open the existing local repository for this playlist?")
            }
        )
        .alert(
            "Error when creating local clone",
            isPresented: $showAlertCloneError,
            actions: {
                Button("OK", action: {} )
            },
            message: {
                Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
            }
        )
    }
    
    private func openExistingClone() {
        Task { @MainActor in
            homeViewCoordinator.disableUI = true
            defer { homeViewCoordinator.disableUI = false }
            
            guard let repositoryReference = self.currentUser.localClonesIndex.first(where: { $0.handle == self.associatedRepositoryHandle }) else {
                print("[Musubi::StaticPlaylistPage] called openExistingClone when clone doesn't exist")
                showAlertCloneError = true
                return
            }
            
            homeViewCoordinator.myReposNavPath.removeLast(homeViewCoordinator.myReposNavPath.count)
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            homeViewCoordinator.openTab = .myRepos
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            
            // TODO: scroll to correct position?
//            homeViewCoordinator.myReposDesiredScrollAnchor =
//            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
//            homeViewCoordinator.myReposDesiredScrollAnchor = .none
            
            homeViewCoordinator.disableUI = false
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            homeViewCoordinator.myReposNavPath.append(repositoryReference)
        }
    }
    
    private func initOrClone() {
        Task { @MainActor in
            homeViewCoordinator.disableUI = true
            defer { homeViewCoordinator.disableUI = false }
            
            if self.currentUser.localClonesIndex.contains(where: { $0.handle == self.associatedRepositoryHandle }) {
                showAlertAlreadyCloned = true
                return
            }
            
                do {
                    homeViewCoordinator.myReposNavPath.removeLast(homeViewCoordinator.myReposNavPath.count)
                    try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                    homeViewCoordinator.openTab = .myRepos
                
                    let repositoryReference = try await self.currentUser.initOrClone(
                        repositoryHandle: Musubi.RepositoryHandle(
                            userID: currentUser.id,
                            playlistID: playlistMetadata.id
                        )
                    )
                    
                    homeViewCoordinator.myReposDesiredScrollAnchor = .bottom
                    try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                    homeViewCoordinator.myReposDesiredScrollAnchor = .none
                    homeViewCoordinator.disableUI = false
                    try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
                    homeViewCoordinator.myReposNavPath.append(repositoryReference)
                } catch {
                    print("[Musubi::StaticPlaylistPage] initOrClone error")
                    print(error.localizedDescription)
                    showAlertCloneError = true
                    return
                }
        }
    }
    
    // TODO: impl
    private func forkOrClone() {
        
    }
}

//#Preview {
//    StaticPlaylistPage()
//}
