// StaticAlbumPage.swift

import SwiftUI

struct StaticAlbumPage: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @Binding var navigationPath: NavigationPath
    
    let album: Spotify.Album
    
    // TODO: find way to automatically init this based on album.name
    // note the obvious sol seems invalid https://forums.swift.org/t/state-messing-with-initializer-flow/25276/3
    @State var name: String
    
    @State private var description: String? = nil
    @State private var coverImage: UIImage?
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList = []
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .album,
            name: $name,
            description: $description,
            coverImage: $coverImage,
            audioTrackList: $audioTrackList,
            associatedPeople: .artists(album.artists),
            date: album.release_date,
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
    
    private func loadContents() async {
        do {
            guard let coverImageURLStr = self.album.images?.first?.url,
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
        
        do {
            let albumTrackListFirstPage = try await SpotifyRequests.Read.albumTrackListFirstPage(
                albumID: album.id,
                userManager: userManager
            )
            self.audioTrackList = Musubi.ViewModel.AudioTrackList.from(
                audioTrackList: albumTrackListFirstPage.items
            )
            
            let restOfTrackList = try await SpotifyRequests.Read.restOfList(
                firstPage: albumTrackListFirstPage,
                userManager: userManager
            )
            guard let restOfTrackList = restOfTrackList as? [Spotify.AudioTrack] else {
                throw Spotify.RequestError.other(detail: "DEVERROR(?) albumTracklist multipage types")
            }
            self.audioTrackList.append(audioTrackList: restOfTrackList)
        } catch {
            // TODO: alert user?
            print("[Musubi::StaticAlbumPage] unable to load tracklist")
            print(error)
        }
    }
}

//#Preview {
//    StaticAlbumPage()
//}
