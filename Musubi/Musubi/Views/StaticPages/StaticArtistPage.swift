// StaticArtistPage.swift

import SwiftUI

struct StaticArtistPage: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    // Indirection to account for SimplifiedArtistObjects (missing images/popularity/etc) in tracks and albums.
    let artistID: Spotify.ID
    @State private var artistMetadata: Spotify.ArtistMetadata? = nil
    
    @State private var topTracks: [Spotify.AudioTrack] = []
    @State private var discographyPreview: [Spotify.AlbumMetadata] = []
    
    @State private var coverImage: UIImage? = nil
    
    private var backgroundHighlightColor: UIColor { coverImage?.meanColor()?.muted() ?? .black }
    
    private let COVER_IMAGE_INITIAL_DIMENSION = min(Musubi.UI.SCREEN_WIDTH, Musubi.UI.SCREEN_HEIGHT)
    private let TITLE_TEXT_HEIGHT: CGFloat = 42
    private let NAVBAR_OFFSET: CGFloat = 90
    private let PLAY_SYMBOL_SIZE = Musubi.UI.PLAY_SYMBOL_SIZE
    
    private let viewID = UUID() // for scroll view coordinate space id
    
    // remember scrollPosition=0 at top and increases as user scrolls down.
    @State private var scrollPosition: CGFloat = 0
    private var coverImageDimension: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: 0.0,
            y1: COVER_IMAGE_INITIAL_DIMENSION,
            x2: -127,
            y2: COVER_IMAGE_INITIAL_DIMENSION * 1.27,
            minY: COVER_IMAGE_INITIAL_DIMENSION / 1.27,
            maxY: COVER_IMAGE_INITIAL_DIMENSION * 1.51
        )
    }
    private var coverImageOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION / 4,
            y1: 1.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION - NAVBAR_OFFSET - TITLE_TEXT_HEIGHT * 0.5,
            y2: 0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var mainTitleOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: 0.0,
            y1: 1.0,
            x2: -61.8,
            y2: 0.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var navTitleOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION - NAVBAR_OFFSET - TITLE_TEXT_HEIGHT * 1.5,
            y1: 0.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION - NAVBAR_OFFSET,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var navBarOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION - NAVBAR_OFFSET - TITLE_TEXT_HEIGHT * 2,
            y1: 0.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION - NAVBAR_OFFSET - TITLE_TEXT_HEIGHT * 0.5,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Musubi.UI.SCREEN_WIDTH, height: coverImageDimension)
                        .clipped()
                        .opacity(coverImageOpacity)
                } else {
                    ProgressView()
                        .frame(width: Musubi.UI.SCREEN_WIDTH, height: coverImageDimension)
                }
            }
            .ignoresSafeArea(.all, edges: [.top, .horizontal])
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            ScrollView {
                VStack(alignment: .leading) {
                    Text(artistMetadata?.name ?? "")
                        .font(.largeTitle.leading(.tight))
                        .bold()
                        .shadow(color: .black, radius: 24.0)
                        .shadow(color: .black, radius: 24.0)
                        .opacity(mainTitleOpacity)
                        .frame(height: COVER_IMAGE_INITIAL_DIMENSION, alignment: .bottom)
                        .padding([.horizontal])
                    
                    ZStack {
                        Color.black
                        VStack(alignment: .leading) {
                            if !topTracks.isEmpty {
                                Text("Top tracks")
                                    .font(.headline)
                                    .padding(.top)
                            }
                            ForEach(topTracks, id: \.self) { audioTrack in
                                Divider()
                                ListCellWrapper(
                                    item: Musubi.ViewModel.AudioTrack(audioTrack: audioTrack),
                                    showThumbnail: true,
                                    customTextStyle: .defaultStyle,
                                    showAudioTrackMenu: true
                                )
                            }
                            if !self.discographyPreview.isEmpty {
                                Text("Discography")
                                    .font(.headline)
                                    .padding(.top)
                                ForEach(discographyPreview) { albumMetadata in
                                    NavigationLink(value: albumMetadata) {
                                        LargeAlbumCell(albumMetadata: albumMetadata)
                                    }
                                }
                                if let artistMetadata = self.artistMetadata {
                                    HStack {
                                        Spacer()
                                        NavigationLink(value: FullDiscographyNavValue(artistMetadata: artistMetadata)) {
                                            Text("See full discography")
                                                .font(.caption)
                                                .bold()
                                                .padding(.horizontal)
                                                .padding(.vertical, 5)
                                                .background(
                                                    Capsule()
                                                        .stroke(.white, lineWidth: 1)
                                                        .opacity(0.5)
                                                )
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            if spotifyPlaybackManager.currentTrack != nil {
                                Rectangle()
                                    .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                                    .padding(6.30 + 3.30)
                                    .hidden()
                            }
                        }
                        .padding([.horizontal, .bottom])
                    }
                }
                .background(
                    GeometryReader { proxy -> Color in
                        Task { @MainActor in
                            scrollPosition = -proxy
                                .frame(in: .named("\(viewID.uuidString)::ScrollView"))
                                .origin.y
                        }
                        return Color.clear
                    }
                )
            }
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "\(viewID.uuidString)::ScrollView")
            .ignoresSafeArea(.all, edges: [.top])
            VStack {
                Color(backgroundHighlightColor)
                    // TODO: this seems unreliable
                    // Note behavior changes depending on order of the following two modifiers.
                    // By calling frame after, we don't need to add any offset for safe area / navbar.
                    .ignoresSafeArea(.all, edges: .top)
                    .frame(height: 1)
                    .opacity(0.81)
                    .background(.ultraThinMaterial)
                    .opacity(navBarOpacity)
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Spacer()
                    Text(artistMetadata?.name ?? "")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(navTitleOpacity)
                    Spacer()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // placeholder to center title
                Image(systemName: "ellipsis")
                    .hidden()
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if !hasLoadedMetadata {
                loadArtistMetadata()
            }
        }
        .onChange(of: self.artistMetadata, initial: false) { _, newValue in
            if newValue != nil {
                loadCoverImage()
                loadTopTracks()
                loadDiscographyPreview()
            }
        }
    }
    
    @State private var hasLoadedMetadata = false
    
    private func loadArtistMetadata() {
        Musubi.Retry.run(
            failableAction: {
                try await self.artistMetadata = SpotifyRequests.Read.artistMetadata(artistID: artistID)
                hasLoadedMetadata = true
            }
        )
    }
    
    private func loadCoverImage() {
        Musubi.Retry.run(
            failableAction: {
                guard let coverImageURLString = artistMetadata?.images?.first?.url,
                      let coverImageURL = URL(string: coverImageURLString)
                else {
                    return
                }
                self.coverImage = try await SpotifyRequests.Read.image(url: coverImageURL)
            }
        )
    }
    
    private func loadTopTracks() {
        Musubi.Retry.run(
            failableAction: {
                guard let artistMetadata = self.artistMetadata else {
                    return
                }
                self.topTracks = try await SpotifyRequests.Read.artistTopTracks(artistID: artistMetadata.id)
            }
        )
    }
    
    private func loadDiscographyPreview() {
        Musubi.Retry.run(
            failableAction: {
                guard let artistMetadata = self.artistMetadata else {
                    return
                }
                self.discographyPreview = try await SpotifyRequests.Read.artistDiscographyPreview(artistID: artistMetadata.id)
            }
        )
    }
    
    struct FullDiscographyNavValue: SpotifyNavigable {
        let artistMetadata: Spotify.ArtistMetadata
    }
    
    struct FullDiscographyPage: View {
        let artistMetadata: Spotify.ArtistMetadata
        
        @State private var fullDiscography: [Spotify.AlbumMetadata] = []
        
        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(fullDiscography) { albumMetadata in
                        NavigationLink(value: albumMetadata) {
                            LargeAlbumCell(albumMetadata: albumMetadata)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Spacer()
                        VStack {
                            Text(artistMetadata.name)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("Discography")
                                .font(.caption)
                        }
                        Spacer()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // placeholder to center title
                    Image(systemName: "ellipsis")
                        .hidden()
                }
            }
            .onAppear(perform: loadFullDiscography)
        }
        
        private func loadFullDiscography() {
            Musubi.Retry.run(
                failableAction: {
                    self.fullDiscography = try await SpotifyRequests.Read.artistDiscographyFull(artistID: artistMetadata.id)
                }
            )
        }
    }
}

fileprivate struct LargeAlbumCell: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    let albumMetadata: Spotify.AlbumMetadata
    
    private var thumbnailURLString: String? {
        guard let images = albumMetadata.images,
              !images.isEmpty
        else {
            return nil
        }
        if images.count >= 2 {
            return images[1].url
        } else {
            return images[0].url
        }
    }
    
    var body: some View {
        ListCell(
            title: albumMetadata.name,
            caption: "\(String(albumMetadata.release_date.prefix(4))) • \(albumMetadata.album_type.capitalized)",
            thumbnailURLString: thumbnailURLString,
            showThumbnail: true,
            customTextStyle: .defaultStyle,
            isActive: spotifyPlaybackManager.currentTrack?.parent?.context.id == albumMetadata.id,
            isPlaying: spotifyPlaybackManager.isPlaying,
            isLarge: true
        )
    }
}

//#Preview {
//    StaticArtistPage()
//}
