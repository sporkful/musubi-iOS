// ListCellView.swift

import SwiftUI

// TODO: playback ability

struct ListCellView: View {
    @Binding private var navigationPath: NavigationPath
    
    let item: SpotifyModelCardable
    let caption: String
    
    init(item: SpotifyModelCardable, navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
        
        self.item = item
        self.caption = {
            switch item.self {
            case is Spotify.Model.AudioTrack:
                let track = item as! Spotify.Model.AudioTrack
                let albumString = if let trackAlbum = track.album {
                    " • " + trackAlbum.name
                } else {
                    ""
                }
                return track.artists.map { $0.name }.joined(separator: ", ") + albumString
            case is Spotify.Model.Album:
                let album = item as! Spotify.Model.Album
                return album.artists.map { $0.name }.joined(separator: ", ")
            default:
                return ""
            }
        }()
    }
    
    private let THUMBNAIL_DIM = Musubi.UIConstants.THUMBNAIL_DIM
    private let MENU_SYMBOL_SIZE = Musubi.UIConstants.MENU_SYMBOL_SIZE
    
    var body: some View {
        HStack {
            HStack {
            if item.images != nil && !(item.images!.isEmpty) {
                AsyncImage(url: URL(string: item.images![0].url)) { image in
                    image.resizable()
                        .scaledToFill()
                        .clipped()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: THUMBNAIL_DIM, height: THUMBNAIL_DIM)
            }
            VStack(alignment: .leading) {
                Text(item.name)
                    .lineLimit(1)
                if caption != "" {
                    Text(caption)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            Spacer()
            }
            .contentShape(Rectangle())
            .allowsHitTesting(item.self is Spotify.Model.AudioTrack)
            .onTapGesture {
                // TODO: implement playback
                // TODO: better error handling (in case allowsHitTesting doesn't work as expected)
                let audioTrack = item.self as! Spotify.Model.AudioTrack
                print("playing \(audioTrack.name)")
            }
            if item.self is Spotify.Model.AudioTrack {
                Menu {
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add to playlist")
                        }
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "text.badge.plus")
                            Text("Add to queue")
                        }
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Go to radio")
                        }
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "smallcircle.circle")
                            Text("View album")
                        }
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "person")
                            Text("View artist")
                        }
                    }
                    Button {
                        // TODO: impl
                    } label: {
                        HStack {
                            Image(systemName: "person.3")
                            Text("Song credits")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: MENU_SYMBOL_SIZE))
                }
            }
        }
    }
}

//#Preview {
//    ListCellView()
//}
