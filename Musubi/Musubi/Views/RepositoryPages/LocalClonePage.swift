// LocalClonePage.swift

import SwiftUI

struct LocalClonePage: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @Binding var navigationPath: NavigationPath
    
    let repositoryHandle: Musubi.RepositoryHandle
    
    @State private var repositoryClone: Musubi.RepositoryClone?
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var coverImageURLString: String?
    
    var body: some View {
        VStack {
            if let repositoryClone = repositoryClone {
                @Bindable var repositoryClone = repositoryClone // TODO: check this
                AudioTrackListPage(
                    navigationPath: $navigationPath,
                    contentType: .musubiLocalClone,
                    name: $name,
                    description: $description,
                    coverImageURLString: $coverImageURLString,
                    audioTrackList: $repositoryClone.stagedAudioTrackList,
                    associatedPeople: .users([]),
                    date: "",
                    toolbarBuilder: {
                        HStack {
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
            }
        }
        .task {
            await loadContents()
        }
    }
    
    // TODO: better error handling (e.g. alert and pop navstack on error)
    private func loadContents() async {
        do {
            let spotifyPlaylistMetadata = try await SpotifyRequests.Read.playlist(
                playlistID: repositoryHandle.playlistID,
                userManager: userManager
            )
            self.coverImageURLString = spotifyPlaylistMetadata.images?.first?.url
            self.name = spotifyPlaylistMetadata.name
            self.description = spotifyPlaylistMetadata.description
            
            self.repositoryClone = try await Musubi.RepositoryClone(
                handle: repositoryHandle,
                userManager: userManager
            )
        } catch {
            // TODO: try again?
            print("[Musubi::LocalClonePage] unable to load")
            print(error)
        }
    }
}

//#Preview {
//    LocalClonePage()
//}
