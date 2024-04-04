// LocalCloneListCell.swift

import SwiftUI

struct LocalCloneListCell: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    let repositoryHandle: Musubi.RepositoryHandle
    
    @State private var spotifyPlaylistMetadata: Spotify.Playlist?
    
    var body: some View {
        VStack {
            if let spotifyPlaylistMetadata = spotifyPlaylistMetadata {
                ListCell(item: spotifyPlaylistMetadata)
            } else {
                Rectangle()
                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                    .hidden()
            }
        }
        .task {
            await loadSpotifyPlaylistMetadata()
        }
    }
    
    private func loadSpotifyPlaylistMetadata() async {
        do {
            self.spotifyPlaylistMetadata = try await SpotifyRequests.Read.playlist(
                playlistID: repositoryHandle.playlistID,
                userManager: userManager
            )
        } catch {
            // TODO: try again?
            print("[Musubi::LocalCloneListCell] unable to load spotify playlist metadata")
            print(error)
        }
    }
}

//#Preview {
//    LocalCloneListCell()
//}
