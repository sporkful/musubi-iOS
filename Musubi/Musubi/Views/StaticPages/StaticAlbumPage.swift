// StaticAlbumPage.swift

import SwiftUI

struct StaticAlbumPage: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @Binding var navigationPath: NavigationPath
    
    let album: Spotify.Album
    
    // TODO: find way to automatically init this based on album.*
    // note the obvious sol seems invalid https://forums.swift.org/t/state-messing-with-initializer-flow/25276/3
    @State var name: String
    @State var coverImageURLString: String?
    
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList = []
    
    @State private var description: String = "" // dummy to satisfy generality of AudioTrackListPage
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .album,
            name: $name,
            description: $description,
            coverImageURLString: $coverImageURLString,
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
    
    @State private var hasLoadedContents = false
    
    private func loadContents() async {
        if hasLoadedContents {
            return
        }
        hasLoadedContents = true
        
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
            print(error.localizedDescription)
            hasLoadedContents = false
        }
    }
}

//#Preview {
//    StaticAlbumPage()
//}
