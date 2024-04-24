// StaticPlaylistPage.swift

import SwiftUI

// TODO: further deduplicate code wrt StaticAlbumPage?

struct StaticPlaylistPage: View {
    @Binding var navigationPath: NavigationPath
    
    let playlistMetadata: Spotify.PlaylistMetadata
    
    @State var name: String
    @State var description: String
    @State var coverImageURLString: String?
    
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList = []
    
    @State private var isViewDisabled = false
    @State private var showAlertCloneError = false
    
    private var repositoryHandle: Musubi.RepositoryHandle {
        Musubi.RepositoryHandle(userID: playlistMetadata.owner.id, playlistID: playlistMetadata.id)
    }
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .spotifyPlaylist,
            name: $name,
            description: $description,
            coverImageURLString: $coverImageURLString,
            audioTrackList: $audioTrackList,
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
                        } else {
                            Button {
                                // TODO: forkOrClone
                            } label: {
                                Image(systemName: "arrow.triangle.branch")
                            }
                        }
                    }
                    Menu {
                        Button {
                            // TODO: impl
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add all tracks in this collection to playlist")
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
            self.audioTrackList = Musubi.ViewModel.AudioTrackList.from(
                audioTrackList: [Spotify.AudioTrack].from(playlistTrackItems: firstPage.items)
            )
            
            let restOfList = try await SpotifyRequests.Read.restOfList(firstPage: firstPage)
            guard let restOfList = restOfList as? [Spotify.PlaylistAudioTrackItem] else {
                throw Spotify.RequestError.other(detail: "DEVERROR(?) playlistTracklist multipage types")
            }
            self.audioTrackList.append(
                audioTrackList: [Spotify.AudioTrack].from(playlistTrackItems: restOfList)
            )
        } catch {
            // TODO: alert user?
            print("[Musubi::StaticPlaylistPage] unable to load tracklist")
            print(error.localizedDescription)
            hasLoadedTrackList = false
        }
    }
    
    private func initOrClone() {
        isViewDisabled = true
        Task {
            do {
                guard let currentUser = Musubi.UserManager.shared.currentUser else {
                    throw Musubi.RepositoryError.cloning(detail: "(StaticPlaylistPage) no current user")
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
