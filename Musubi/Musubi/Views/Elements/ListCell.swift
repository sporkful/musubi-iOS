// ListCell.swift

import SwiftUI

protocol CustomPreviewable {
    var title: String { get }
    var caption: String? { get }
    var thumbnailURLString: String? { get }
}

extension Musubi.RepositoryReference: CustomPreviewable {
    var title: String { self.externalMetadata?.name ?? "(Loading local clone...)" }
    var caption: String? { self.externalMetadata?.descriptionTextFromHTML }
    var thumbnailURLString: String? { self.externalMetadata?.images?.last?.url }
}

extension Spotify.LoggedInUser: CustomPreviewable {
    var title: String { self.name }
    var caption: String? { "Spotify User (Logged In)" }
    var thumbnailURLString: String? { self.images?.last?.url }
}

extension Spotify.OtherUser: CustomPreviewable {
    var title: String { self.name }
    var caption: String? { "Spotify User" }
    var thumbnailURLString: String? { self.images?.last?.url }
}

extension Spotify.AudioTrack: CustomPreviewable {
    var title: String { self.name }
    
    var caption: String? {
        let albumString = if let album = self.album {
            " • " + album.name
        } else {
            ""
        }
        return self.artists.map { $0.name }.joined(separator: ", ") + albumString
    }
    
    var thumbnailURLString: String? { self.images?.last?.url }
}

extension Spotify.ArtistMetadata: CustomPreviewable {
    var title: String { self.name }
    var caption: String? { "Artist" }
    var thumbnailURLString: String? { self.images?.last?.url }
}

extension Spotify.AlbumMetadata: CustomPreviewable {
    var title: String { self.name }
    var caption: String? { self.artists.map { $0.name }.joined(separator: ", ") }
    var thumbnailURLString: String? { self.images?.last?.url }
}

extension Spotify.PlaylistMetadata: CustomPreviewable {
    var title: String { self.name }
    var caption: String? { self.descriptionTextFromHTML }
    var thumbnailURLString: String? { self.images?.last?.url }
}

struct ListCellWrapper<Item: CustomPreviewable>: View {
    let item: Item
    let showThumbnail: Bool
    let customTextStyle: ListCell.CustomTextStyle
    var isPlaying: Bool = false
    
    var body: some View {
        ListCell(
            title: item.title,
            caption: item.caption,
            thumbnailURLString: item.thumbnailURLString,
            showThumbnail: showThumbnail,
            customTextStyle: customTextStyle,
            isPlaying: isPlaying
        )
    }
}

struct ListCell: View {
    let title: String
    let caption: String?
    let thumbnailURLString: String?
    let showThumbnail: Bool
    let customTextStyle: CustomTextStyle  // TODO: turn into custom view modifier?
    var isPlaying: Bool = false
    
    struct CustomTextStyle: Equatable {
        var color: CustomColor
        var bold: Bool
        
        enum CustomColor: Equatable {
            case none, green, red
            
            var color: Color {
                switch self {
                case .none: .white
                case .green: .green
                case .red: .red
                }
            }
        }
        
        static let defaultStyle = Self(color: .none, bold: false)
    }
    
    var body: some View {
        HStack {
            if showThumbnail {
                if let thumbnailURLString = self.thumbnailURLString,
                   let thumbnailURL = URL(string: thumbnailURLString)
                {
                    RetryableAsyncImage(
                        url: thumbnailURL,
                        width: Musubi.UI.ImageDimension.cellThumbnail.rawValue,
                        height: Musubi.UI.ImageDimension.cellThumbnail.rawValue
                    )
                }
                else {
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
                HStack {
                    if isPlaying {
                        Image(systemName: "chart.bar.fill")
                            .symbolEffect(.variableColor.cumulative.hideInactiveLayers.reversing, options: .repeating, isActive: true)
                    }
                    Text(title)
                        .lineLimit(1)
                }
                .foregroundStyle(isPlaying ? .green : .white)
                if let caption = self.caption {
                    Text(caption)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
        .foregroundColor(customTextStyle.color.color)
        .bold(customTextStyle.bold)
    }
}

//#Preview {
//    ListCell()
//}
