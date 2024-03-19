// StaticPlaylistPage.swift

import SwiftUI

// TODO: further deduplicate code wrt StaticAlbumPage?

struct StaticPlaylistPage: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @Binding var navigationPath: NavigationPath
    
    let playlist: Spotify.Playlist
    
    @State var name: String
    
    @State private var description: String? = nil
    @State private var coverImage: UIImage?
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList = []
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .playlist,
            name: $name,
            description: $description,
            coverImage: $coverImage,
            audioTrackList: $audioTrackList,
            associatedPeople: .users([playlist.owner]),
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
        .task {
            await loadContents()
        }
    }
    
    @MainActor
    private func loadContents() async {
        do {
            let audioTrackList = try await SpotifyRequests.Read.playlistTracklist(
                playlistID: playlist.id,
                userManager: userManager
            )
            self.audioTrackList = Musubi.ViewModel.AudioTrackList.from(audioTrackList: audioTrackList)
        } catch {
            // TODO: alert user?
            print("[Musubi::StaticAlbumPage] unable to load tracklist")
            print(error)
        }
        
        do {
            guard let coverImageURLStr = self.playlist.images?.first?.url,
                  let coverImageURL = URL(string: coverImageURLStr)
            else {
                throw Musubi.UIError.any(detail: "StaticAlbumPage no image url found")
            }
            let (imageData, _) = try await URLSession.shared.data(from: coverImageURL)
            self.coverImage = UIImage(data: imageData)
        } catch {
            // TODO: try again?
            print("[Musubi::StaticAlbumPage] unable to load cover image")
            print(error)
        }
    }
}

//#Preview {
//    StaticPlaylistPage()
//}
