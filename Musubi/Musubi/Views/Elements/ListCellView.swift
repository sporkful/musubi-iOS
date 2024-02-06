// ListCellView.swift

import SwiftUI

struct ListCellView: View {
    let item: SpotifyModelCardable
    let caption: String
    
    init(item: SpotifyModelCardable) {
        self.item = item
        self.caption = {
            switch item.self {
            case is Spotify.Model.AudioTrack:
                let audioTrack = item as! Spotify.Model.AudioTrack
                let albumString = if let album = audioTrack.album {
                    " • " + album.name
                } else {
                    ""
                }
                return audioTrack.artists.map { $0.name }.joined(separator: ", ") + albumString
            case is Spotify.Model.Album:
                let album = item as! Spotify.Model.Album
                return album.artists.map { $0.name }.joined(separator: ", ")
            default:
                return ""
            }
        }()
    }
    
    var body: some View {
        HStack {
            if item.images != nil && !(item.images!.isEmpty) {
                AsyncImage(url: URL(string: item.images![0].url)) { loadedImage in
                    loadedImage
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: Musubi.UIConstants.ImageDimension.cellThumbnail.rawValue)
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
        .frame(height: Musubi.UIConstants.ImageDimension.cellThumbnail.rawValue)
    }
}

//#Preview {
//    ListCellView()
//}
