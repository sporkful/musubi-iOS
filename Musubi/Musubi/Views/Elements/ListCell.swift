// ListCell.swift

import SwiftUI

struct ListCell: View {
    private let title: String
    private let caption: String
    private let thumbnailURL: URL?
    private let showThumbnail: Bool
    
    init(repositoryReference: Musubi.RepositoryReference, showThumbnail: Bool = true) {
        self.title = repositoryReference.externalMetadata.name
        self.caption = repositoryReference.externalMetadata.description
        if let coverImageURLString = repositoryReference.externalMetadata.coverImageURLString {
            self.thumbnailURL = URL(string: coverImageURLString)
        } else {
            self.thumbnailURL = nil
        }
        self.showThumbnail = showThumbnail
    }
    
    init(item: SpotifyPreviewable, showThumbnail: Bool = true) {
        self.title = item.name
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
            case is Spotify.AlbumMetadata:
                let album = item as! Spotify.AlbumMetadata
                return album.artists.map { $0.name }.joined(separator: ", ")
            default:
                return ""
            }
        }()
        
        if let thumbnailURLString = item.images?.last?.url {
            self.thumbnailURL = URL(string: thumbnailURLString)
        } else {
            self.thumbnailURL = nil
        }
        self.showThumbnail = showThumbnail
    }
    
    var body: some View {
        HStack {
            if showThumbnail {
                if let thumbnailURL = thumbnailURL {
                    RetryableAsyncImage(
                        url: thumbnailURL,
                        width: Musubi.UI.ImageDimension.cellThumbnail.rawValue,
                        height: Musubi.UI.ImageDimension.cellThumbnail.rawValue
                    )
                } else {
                    ZStack {
                        Rectangle()
                            .fill(.gray)
                        Image(systemName: "music.note")
                    }
                    .frame(
                        width: Musubi.UI.ImageDimension.cellThumbnail.rawValue,
                        height: Musubi.UI.ImageDimension.cellThumbnail.rawValue
                    )
                    .opacity(0.5)
                }
            }
            VStack(alignment: .leading) {
                Text(title)
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
