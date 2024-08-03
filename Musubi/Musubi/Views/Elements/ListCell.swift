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
    @Environment(\.openURL) private var openURL
    
    let item: Item
    let showThumbnail: Bool
    let customTextStyle: ListCell.CustomTextStyle
    
    // e.g. albums on artist page
    var isLarge: Bool = false
    
    // for if item is Musubi.ViewModel.AudioTrack
    var showAudioTrackMenu: Bool = false
    @State private var showAlertErrorStartPlayback = false
    
    var body: some View {
        @Bindable var spotifyPlaybackManager = spotifyPlaybackManager
        
        if let audioTrack = item as? Musubi.ViewModel.AudioTrack {
            HStack {
                ListCell(
                    title: item.title,
                    caption: item.caption,
                    thumbnailURLString: item.thumbnailURLString,
                    showThumbnail: showThumbnail,
                    customTextStyle: customTextStyle,
                    isActive: spotifyPlaybackManager.currentTrack == audioTrack
                    // TODO: clean up this hack (refer to ViewModel.AudioTrack)
                    && spotifyPlaybackManager.currentTrack?.parent?.context.id == audioTrack.parent?.context.id,
                    isPlaying: spotifyPlaybackManager.isPlaying,
                    isLarge: isLarge
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        do {
                            try await spotifyPlaybackManager.play(audioTrack: audioTrack)
                        } catch {
                            // TODO: handle
                            print(error)
                            showAlertErrorStartPlayback = true
                        }
                    }
                }
                if showAudioTrackMenu {
                    SingleAudioTrackMenu(
                        audioTrack: audioTrack,
                        showParentSheet: Binding.constant(false)
                    )
                }
            }
            .alert(
                "No playback device selected",
                isPresented: $spotifyPlaybackManager.showAlertNoDevice,
                actions: {},
                message: {
                    Text(spotifyPlaybackManager.NO_DEVICE_ERROR_MESSAGE)
                }
            )
            .alert(
                "Please open the official Spotify app to complete your action, then return to this app.",
                isPresented: $spotifyPlaybackManager.showAlertOpenSpotifyOnTargetDevice,
                actions: {
                    Button(
                        action: {
                            openURL(URL(string: "spotify:")!)
                        },
                        label: {
                            Text("Open Spotify")
                        }
                    )
                },
                message: {
                    Text("This is due to a limitation in Spotify's API. Sorry for the inconvenience!")
                }
            )
            .alert(
                "Error when starting playback",
                isPresented: $showAlertErrorStartPlayback,
                actions: {},
                message: {
                    Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
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
                isPlaying: spotifyPlaybackManager.isPlaying,
                isLarge: isLarge
            )
        } else {
            ListCell(
                title: item.title,
                caption: item.caption,
                thumbnailURLString: item.thumbnailURLString,
                showThumbnail: showThumbnail,
                customTextStyle: customTextStyle,
                isLarge: isLarge
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
    var isLarge: Bool = false
    
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
    
    @State private var thumbnail: UIImage? = nil
    private var THUMBNAIL_DIMENSION: CGFloat {
        if isLarge {
            Musubi.UI.ImageDimension.largeCellThumbnail.rawValue
        } else {
            Musubi.UI.ImageDimension.cellThumbnail.rawValue
        }
    }
    
    var body: some View {
        HStack {
            if showThumbnail {
                if let thumbnailURLString = self.thumbnailURLString,
                   URL(string: thumbnailURLString) != nil
                {
                    if let thumbnail = self.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: THUMBNAIL_DIMENSION, height: THUMBNAIL_DIMENSION)
                            .clipped()
                    } else {
                        ProgressView()
                            .frame(width: THUMBNAIL_DIMENSION, height: THUMBNAIL_DIMENSION)
                            .onAppear(perform: loadThumbnail)
                    }
                }
                else {
                    ZStack {
                        Rectangle()
                            .fill(.gray)
                        Image(systemName: "music.note")
                    }
                    .frame(width: THUMBNAIL_DIMENSION, height: THUMBNAIL_DIMENSION)
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
                        .font(isLarge ? .title3 : .body)
                        .bold(isLarge || customTextStyle.bold)
                        .lineLimit(1)
                }
                .foregroundStyle((isActive && customTextStyle.color == .none) ? .green : customTextStyle.color.color)
                if let caption = self.caption {
                    Text(caption)
                        .font(.caption)
                        .lineLimit(1)
                        .opacity(0.81)
                }
            }
            Spacer()
        }
        .frame(height: THUMBNAIL_DIMENSION)
        .foregroundColor(customTextStyle.color.color)
        .bold(customTextStyle.bold)
    }
    
    private func loadThumbnail() {
        guard let thumbnailURLString = self.thumbnailURLString,
              let thumbnailURL = URL(string: thumbnailURLString)
        else {
            return
        }
        
        Musubi.Retry.run(
            failableAction: {
                self.thumbnail = try await SpotifyRequests.Read.image(url: thumbnailURL)
            }
        )
    }
}

//#Preview {
//    ListCell()
//}
