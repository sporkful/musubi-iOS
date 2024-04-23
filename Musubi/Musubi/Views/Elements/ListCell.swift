// ListCell.swift

import SwiftUI

struct ListCell: View {
    private let title: String
    private let caption: String
    private let imageURL: URL?
    
    init(title: String, caption: String, imageURL: URL?) {
        self.title = title
        self.caption = caption
        self.imageURL = imageURL
    }
    
    init(repositoryReference: Musubi.RepositoryReference) {
        self.title = repositoryReference.externalMetadata.name
        self.caption = repositoryReference.externalMetadata.description
        if let coverImageURLString = repositoryReference.externalMetadata.coverImageURLString {
            self.imageURL = URL(string: coverImageURLString)
        } else {
            self.imageURL = nil
        }
    }
    
    init(item: SpotifyModelCardable) {
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
        
        if let image = item.images?.first {
            self.imageURL = URL(string: image.url)
        } else {
            self.imageURL = nil
        }
    }
    
    var body: some View {
        HStack {
            if let imageURL = imageURL {
                RetryableAsyncImage(
                    url: imageURL,
                    width: Musubi.UI.ImageDimension.cellThumbnail.rawValue,
                    height: Musubi.UI.ImageDimension.cellThumbnail.rawValue
                )
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
