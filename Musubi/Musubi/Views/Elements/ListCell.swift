// ListCell.swift

import SwiftUI

struct ListCell: View {
    let item: SpotifyModelCardable
    let caption: String
    
    init(item: SpotifyModelCardable) {
        self.item = item
        self.caption = {
            switch item.self {
            case is Spotify.AudioTrack:
                let audioTrack = item as! Spotify.AudioTrack
                let albumString = if let album = audioTrack.album {
                    " • " + album.name
                } else {
                    ""
                }
                return audioTrack.artists.map { $0.name }.joined(separator: ", ") + albumString
            case is Spotify.Album:
                let album = item as! Spotify.Album
                return album.artists.map { $0.name }.joined(separator: ", ")
            default:
                return ""
            }
        }()
    }
    
    var body: some View {
        HStack {
            if item.images != nil && !(item.images!.isEmpty),
               let url = URL(string: item.images![0].url)
            {
                RetryableAsyncImage(url: url)
                    .frame(width: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
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
        .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
    }
}

//#Preview {
//    ListCell()
//}
