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

extension Musubi.ViewModel.AudioTrack: CustomPreviewable {
    var title: String { self.audioTrack.name }
    var caption: String? {
        if self.parent?.context is Spotify.AlbumMetadata {
            return self.audioTrack.artists.map { $0.name }.joined(separator: ", ")
        } else {
            return fullCaption
        }
    }
    var fullCaption: String {
        let albumString = if let album = self.audioTrack.album {
            " • " + album.name
        } else {
            ""
        }
        return self.audioTrack.artists.map { $0.name }.joined(separator: ", ") + albumString
    }
    var thumbnailURLString: String? { self.audioTrack.images?.last?.url }
}

extension Musubi.RepositoryCommit: CustomPreviewable {
    var title: String { self.commit.message }
    var caption: String? { self.commit.date.formatted() }
    var thumbnailURLString: String? { nil }
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

struct ListCellWrapper<Item: CustomPreviewable>: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    let item: Item
    let showThumbnail: Bool
    let customTextStyle: ListCell.CustomTextStyle
    
    // for if item is Musubi.ViewModel.AudioTrack
    var showAudioTrackMenu: Bool = false
    @State private var showAlertErrorStartPlayback = false
    
    var body: some View {
        if let audioTrack = item as? Musubi.ViewModel.AudioTrack {
            HStack {
                ListCell(
                    title: item.title,
                    caption: item.caption,
                    thumbnailURLString: item.thumbnailURLString,
                    showThumbnail: showThumbnail,
                    customTextStyle: customTextStyle,
                    isActive: spotifyPlaybackManager.currentTrack == audioTrack,
                    isPlaying: spotifyPlaybackManager.isPlaying
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        do {
                            try await spotifyPlaybackManager.play(audioTrack: audioTrack)
                        } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                            showAlertErrorStartPlayback = true
                        } catch {
                            // TODO: handle
                            print(error)
                        }
                    }
                }
                if showAudioTrackMenu {
                    SingleAudioTrackMenu(
                        audioTrack: audioTrack,
                        showParentSheet: Binding.constant(false),
                        isInListCell: true
                    )
                }
            }
            .alert(
                "Error when starting playback",
                isPresented: $showAlertErrorStartPlayback,
                actions: {},
                message: {
                    Text(SpotifyPlaybackManager.PLAY_ERROR_MESSAGE)
                }
            )
        } else if let audioTrackListContext = item as? AudioTrackListContext {
            ListCell(
                title: item.title,
                caption: item.caption,
                thumbnailURLString: item.thumbnailURLString,
                showThumbnail: showThumbnail,
                customTextStyle: customTextStyle,
                isActive: spotifyPlaybackManager.currentTrack?.parent?.context.id == audioTrackListContext.id,
                isPlaying: spotifyPlaybackManager.isPlaying
            )
        } else {
            ListCell(
                title: item.title,
                caption: item.caption,
                thumbnailURLString: item.thumbnailURLString,
                showThumbnail: showThumbnail,
                customTextStyle: customTextStyle
            )
        }
    }
}

struct ListCell: View {
    let title: String
    let caption: String?
    let thumbnailURLString: String?
    let showThumbnail: Bool
    let customTextStyle: CustomTextStyle  // TODO: turn into custom view modifier?
    var isActive: Bool = false
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
                    if isActive {
                        if isPlaying {
                            Image(systemName: "waveform")
                                .symbolEffect(
                                    .variableColor.cumulative.reversing.dimInactiveLayers,
                                    options: .repeating.speed(1.70),
                                    isActive: true
                                )
                        } else {
                            Image(systemName: "waveform")
                                .opacity(0.5)
                        }
                    }
                    Text(title)
                        .lineLimit(1)
                }
                .foregroundStyle((isActive && customTextStyle.color == .none) ? .green : customTextStyle.color.color)
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
