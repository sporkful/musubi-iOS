// StaticPlaylistPage.swift

import SwiftUI

struct StaticPlaylistPage: View {
    @Binding var navigationPath: NavigationPath
    
    let playlistMetadata: Spotify.PlaylistMetadata
    
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList?
    
    @State private var showSheetAddToSelectableClones = false
    
    @State private var isViewDisabled = false
    @State private var showAlertCloneError = false
    
    private var repositoryHandle: Musubi.RepositoryHandle {
        Musubi.RepositoryHandle(userID: playlistMetadata.owner.id, playlistID: playlistMetadata.id)
    }
    
    var body: some View {
        // TODO: safe way to remove dummy outer VStack?
        VStack {
        if let audioTrackList = self.audioTrackList {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .spotifyPlaylist,
            name: Binding.constant(playlistMetadata.name),
            description: Binding.constant(playlistMetadata.descriptionTextFromHTML),
            coverImageURLString: Binding.constant(playlistMetadata.images?.first?.url),
            audioTrackList: audioTrackList,
            showAudioTrackThumbnails: true,
            associatedPeople: .users([playlistMetadata.owner]),
            miscCaption: nil,
            toolbarBuilder: {
                HStack {
                    if let currentUser = Musubi.UserManager.shared.currentUser,
                       !currentUser.localClonesIndex.contains(where: { $0.handle == self.repositoryHandle })
                    {
                        if playlistMetadata.owner.id == currentUser.id {
                            Button {
                                initOrClone()
                            } label: {
                                Image(systemName: "square.and.arrow.down.on.square")
                            }
//                        } else {
//                            Button {
//                                // TODO: forkOrClone
//                            } label: {
//                                Image(systemName: "arrow.triangle.branch")
//                            }
                        }
                    }
                    Menu {
                        Button {
                            showSheetAddToSelectableClones = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add tracks from this collection to")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: Musubi.UI.MENU_SYMBOL_SIZE))
                            .frame(height: Musubi.UI.MENU_SYMBOL_SIZE)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                    Button {
                        // TODO: impl
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                        // TODO: opacity depending on toggle state
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                    }
                }
            }
        )
        .sheet(isPresented: $showSheetAddToSelectableClones) {
            AddToSelectableLocalClonesSheet(
                audioTrackList: audioTrackList,
                showSheet: $showSheetAddToSelectableClones
            )
        }
        }
        }
        .disabled(isViewDisabled)
        .alert("Musubi - failed to clone repo", isPresented: $showAlertCloneError, actions: {})
        .task {
            await loadAudioTrackList()
        }
    }
    
    @State private var hasLoadedTrackList = false
    
    private func loadAudioTrackList() async {
        if hasLoadedTrackList {
            return
        }
        hasLoadedTrackList = true
        
        do {
            let firstPage = try await SpotifyRequests.Read.playlistFirstAudioTrackPage(playlistID: playlistMetadata.id)
            self.audioTrackList = try await Musubi.ViewModel.AudioTrackList(
                audioTracks: [Spotify.AudioTrack].from(playlistTrackItems: firstPage.items)
            )
            
            let restOfList = try await SpotifyRequests.Read.restOfList(firstPage: firstPage)
            try await self.audioTrackList!.append(
                audioTracks: [Spotify.AudioTrack].from(playlistTrackItems: restOfList)
            )
        } catch {
            // TODO: alert user?
            print("[Musubi::StaticPlaylistPage] unable to load tracklist")
            print(error.localizedDescription)
            hasLoadedTrackList = false
        }
    }
    
    // TODO: automatically (switch tabs and) open clone upon success
    // TODO: also pop this off navstack upon success so users don't get confused?
    private func initOrClone() {
        isViewDisabled = true
        Task {
            do {
                guard let currentUser = Musubi.UserManager.shared.currentUser else {
                    throw Musubi.Repository.Error.cloning(detail: "(StaticPlaylistPage) no current user")
                }
                try await currentUser.initOrClone(
                    repositoryHandle: Musubi.RepositoryHandle(
                        userID: currentUser.id,
                        playlistID: playlistMetadata.id
                    )
                )
            } catch {
                print("[Musubi::StaticPlaylistPage] initOrClone error")
                print(error.localizedDescription)
            }
            isViewDisabled = false
        }
    }
}

//#Preview {
//    StaticPlaylistPage()
//}
