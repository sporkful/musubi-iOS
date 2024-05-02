// StaticAlbumPage.swift

import SwiftUI

struct StaticAlbumPage: View {
    @Binding var navigationPath: NavigationPath
    
    let albumMetadata: Spotify.AlbumMetadata
    
    // TODO: find way to automatically init this based on album.*
    // note the obvious sol seems invalid https://forums.swift.org/t/state-messing-with-initializer-flow/25276/3
    @State var name: String
    @State var coverImageURLString: String?
    
    @State private var audioTrackList: Musubi.ViewModel.AudioTrackList = []
    
    @State private var description: String = "" // dummy to satisfy generality of AudioTrackListPage
    
    @State private var showSheetAddToSelectableClones = false
    
    var body: some View {
        AudioTrackListPage(
            navigationPath: $navigationPath,
            contentType: .album,
            name: $name,
            description: $description,
            coverImageURLString: $coverImageURLString,
            audioTrackList: $audioTrackList,
            showAudioTrackThumbnails: false,
            associatedPeople: .artists(albumMetadata.artists),
            miscCaption: "Release Date: \(albumMetadata.release_date)",
            toolbarBuilder: {
                HStack {
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
                audioTrackList: $audioTrackList,
                showSheet: $showSheetAddToSelectableClones
            )
        }
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
            let firstPage = try await SpotifyRequests.Read.albumFirstAudioTrackPage(albumID: albumMetadata.id)
            self.audioTrackList = Musubi.ViewModel.AudioTrackList.from(
                audioTrackList: firstPage.items.map { audioTrack in
                    Spotify.AudioTrack(audioTrack: audioTrack, withAlbumMetadata: self.albumMetadata)
                }
            )
            
            let restOfList = try await SpotifyRequests.Read.restOfList(firstPage: firstPage)
            guard let restOfList = restOfList as? [Spotify.AudioTrack] else {
                throw Spotify.RequestError.other(detail: "DEVERROR(?) albumTracklist multipage types")
            }
            self.audioTrackList.append(
                audioTrackList: restOfList.map { audioTrack in
                    Spotify.AudioTrack(audioTrack: audioTrack, withAlbumMetadata: self.albumMetadata)
                }
            )
        } catch {
            // TODO: alert user?
            print("[Musubi::StaticAlbumPage] unable to load tracklist")
            print(error.localizedDescription)
            hasLoadedTrackList = false
        }
    }
}

//#Preview {
//    StaticAlbumPage()
//}
