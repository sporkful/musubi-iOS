// AlbumStaticPageView.swift

import SwiftUI

struct AlbumStaticPageView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    let album: Spotify.Model.Album
    
    @Binding var navigationPath: NavigationPath
    
    @State private var audioTrackList: [Spotify.Model.AudioTrack] = []
    
    @State private var image: UIImage?
    private let ALBUM_COVER_DIM = Musubi.UIConstants.ImageDimension.albumCover.rawValue
    
    var body: some View {
        ScrollView {
            VStack {
                VStack(alignment: .leading) {
                    if let image = image {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                                .frame(width: ALBUM_COVER_DIM, height: ALBUM_COVER_DIM)
                            Spacer()
                        }
                    }
                    Text(album.name)
                        .font(.title)
                        .fontWeight(.bold)
                    HStack {
                        ForEach(Array(zip(album.artists.indices, album.artists)), id: \.0) { index, artist in
                            if index != 0 {
                                Text("•")
                            }
                            Button {
                                navigationPath.append(artist)
                            } label: {
                                Text(artist.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    Text("Album • \(album.release_date)")
                        .font(.caption)
                }
                ForEach(audioTrackList) { audioTrack in
                    Divider()
                    AudioTrackListCellView(audioTrack: audioTrack, navigationPath: $navigationPath)
                }
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(album.name)
                        .font(.headline)
                }
            }
        }
        .task {
            await loadContents()
        }
    }
    
    @MainActor
    func loadContents() async {
        do {
            self.audioTrackList = try await Spotify.Requests.Read.albumTracklist(
                albumID: album.id,
                userManager: userManager
            )
        } catch {
            // TODO: alert user?
            print("[Musubi::AlbumStaticPageView] unable to load tracklist")
            print(error)
        }
        
        do {
            guard let imageURLString = self.album.images?.first?.url,
                  let imageURL = URL(string: imageURLString)
            else {
                throw Musubi.UIError.any(detail: "AlbumStaticPageView no image url found")
            }
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            self.image = UIImage(data: imageData)
        } catch {
            print("[Musubi::AlbumStaticPageView] unable to load image")
            print(error)
        }
    }
}

//#Preview {
//    AlbumStaticPageView()
//}
