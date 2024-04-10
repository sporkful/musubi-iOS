// StaticPlaylistPage.swift

import SwiftUI

// TODO: further deduplicate code wrt StaticAlbumPage?

struct StaticPlaylistPage: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @Binding var navigationPath: NavigationPath
    
    let playlist: Spotify.Playlist
    
    @State var name: String
    @State var description: String
    @State var coverImageURLString: String?
    
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList = []
    
    @State private var isViewDisabled = false
    @State private var showAlertCloneError = false
    
    private var repositoryHandle: Musubi.RepositoryHandle {
        Musubi.RepositoryHandle(userID: playlist.owner.id, playlistID: playlist.id)
    }
    
    private var isAlreadyLocalClone: Bool {
        if let currentUser = userManager.currentUser {
            return currentUser.localClonesIndex.contains(where: { $0.handle == self.repositoryHandle })
        } else {
            return true
        }
    }
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .spotifyPlaylist,
            name: $name,
            description: $description,
            coverImageURLString: $coverImageURLString,
            audioTrackList: $audioTrackList,
            associatedPeople: .users([playlist.owner]),
            date: "",
            toolbarBuilder: {
                HStack {
                    if !isAlreadyLocalClone {
                        if playlist.owner.id == userManager.currentUser?.id {
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
            await loadContents()
        }
    }
    
    @State private var hasLoadedContents = false
    
    private func loadContents() async {
        if hasLoadedContents {
            return
        }
        hasLoadedContents = true
        
        do {
            let playlistTrackListFirstPage = try await SpotifyRequests.Read.playlistTrackListFirstPage(
                playlistID: playlist.id,
                userManager: userManager
            )
            self.audioTrackList = Musubi.ViewModel.AudioTrackList.from(
                audioTrackList: [Spotify.AudioTrack].from(playlistTrackItems: playlistTrackListFirstPage.items)
            )
            
            let restOfTrackList = try await SpotifyRequests.Read.restOfList(
                firstPage: playlistTrackListFirstPage,
                userManager: userManager
            )
            guard let restOfTrackList = restOfTrackList as? [Spotify.Playlist.AudioTrackItem] else {
                throw Spotify.RequestError.other(detail: "DEVERROR(?) playlistTracklist multipage types")
            }
            self.audioTrackList.append(
                audioTrackList: [Spotify.AudioTrack].from(playlistTrackItems: restOfTrackList)
            )
        } catch {
            // TODO: alert user?
            print("[Musubi::StaticPlaylistPage] unable to load tracklist")
            print(error)
            hasLoadedContents = false
        }
    }
    
    private func initOrClone() {
        isViewDisabled = true
        Task {
            do {
                // TODO: clean up reference-spaghetti between User and UserManager
                try await userManager.currentUser?.initOrClone(
                    repositoryHandle: Musubi.RepositoryHandle(
                        userID: userManager.currentUser?.id ?? "",
                        playlistID: playlist.id
                    ),
                    userManager: userManager
                )
            } catch {
                print("[Musubi::StaticPlaylistPage] initOrClone error")
                print(error)
            }
            isViewDisabled = false
        }
    }
}

//#Preview {
//    StaticPlaylistPage()
//}
