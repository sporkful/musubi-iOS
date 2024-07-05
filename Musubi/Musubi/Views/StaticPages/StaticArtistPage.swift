// StaticArtistPage.swift

import SwiftUI

// Indirection to account for SimplifiedArtistObjects (missing images/popularity/etc) in tracks and albums.
struct StaticArtistPage: View {
    let artistID: Spotify.ID
    
    @State private var artistMetadata: Spotify.ArtistMetadata? = nil
    
    var body: some View {
        if let artistMetadata = self.artistMetadata {
            HydratedStaticArtistPage(artistMetadata: artistMetadata)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear(perform: loadArtistMetadata)
        }
    }
    
    private func loadArtistMetadata() {
        Task { @MainActor in
            while true {
                do {
                    try await self.artistMetadata = SpotifyRequests.Read.artistMetadata(artistID: artistID)
                    return
                } catch {
//                    print("retrying")
                }
                do {
                    try await Task.sleep(until: .now + .seconds(3), clock: .continuous)
                } catch {
//                    print("giving up")
                    break // task was cancelled
                }
            }
        }
    }
}

fileprivate struct HydratedStaticArtistPage: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    let artistMetadata: Spotify.ArtistMetadata
    
    @State private var topTracks: Musubi.ViewModel.AudioTrackList? = nil
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
                    Text(artistMetadata.name)
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
                            if let topTracks = self.topTracks {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("Popular")
                                            .font(.headline)
                                            .padding(.top)
                                        CustomToolbar(parentAudioTrackList: topTracks)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    }
                                    ForEach(topTracks.contents, id: \.self) { audioTrack in
                                        Divider()
                                        ListCellWrapper(
                                            item: audioTrack,
                                            showThumbnail: true,
                                            customTextStyle: .defaultStyle,
                                            showAudioTrackMenu: true
                                        )
                                    }
                                }
                            }
                            if !self.discographyPreview.isEmpty {
                                Text("Discography")
                                    .font(.headline)
                                    .padding(.top)
                                ForEach(discographyPreview) { albumMetadata in
                                    NavigationLink(value: albumMetadata) {
                                        ListCellWrapper(
                                            item: albumMetadata,
                                            showThumbnail: true,
                                            customTextStyle: .defaultStyle
                                        )
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
                    Text(artistMetadata.name)
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
            if !hasLoaded {
                loadCoverImage()
                loadTopTracks()
                loadDiscographyPreview()
                hasLoaded = true
            }
        }
    }
    
    @State private var hasLoaded = false
    
    // TODO: share logic with RetryableAsyncImage?
    private func loadCoverImage() {
        guard let coverImageURLString = artistMetadata.coverImageURLString,
              let coverImageURL = URL(string: coverImageURLString)
        else {
            return
        }
        
        Task { @MainActor in
            while true {
                do {
                    self.coverImage = try await SpotifyRequests.Read.image(url: coverImageURL)
                    return
                } catch {
//                    print("[Musubi::RetryableAsyncImage] failed to load image")
//                    print(error)
//                    print("[Musubi::RetryableAsyncImage] retrying...")
                }
                do {
                    try await Task.sleep(until: .now + .seconds(3), clock: .continuous)
                } catch {
//                    print("[Musubi::RetryableAsyncImage] giving up")
                    break // task was cancelled
                }
            }
        }
    }
    
    private func loadTopTracks() {
        Task { @MainActor in
            self.topTracks = Musubi.ViewModel.AudioTrackList(artistMetadata: artistMetadata)
        }
    }
    
    private func loadDiscographyPreview() {
        Task { @MainActor in
            self.discographyPreview = try await SpotifyRequests.Read.artistDiscographyPreview(artistID: artistMetadata.id)
        }
    }
}

fileprivate struct CustomToolbar: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    @Bindable var parentAudioTrackList: Musubi.ViewModel.AudioTrackList
    
    @State private var showAlertErrorStartPlayback = false
    
    var body: some View {
        HStack {
            Spacer()
            // TODO: deduplicate wrt AudioTrackListPage
            // TODO: figure out better way to extract context's audioTrackList (no need to case / repeat code)
            if case .remote(audioTrackList: let audioTrackList) = spotifyPlaybackManager.context,
               audioTrackList?.context.id == parentAudioTrackList.context.id
            {
                if spotifyPlaybackManager.isPlaying {
                    Button {
                        Task { try await spotifyPlaybackManager.pause() }
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                    }
                } else {
                    Button {
                        Task { try await spotifyPlaybackManager.resume() }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                    }
                }
            }
            else if case .local(audioTrackList: let audioTrackList) = spotifyPlaybackManager.context,
                    audioTrackList.context.id == parentAudioTrackList.context.id
            {
                if spotifyPlaybackManager.isPlaying {
                    Button {
                        Task { try await spotifyPlaybackManager.pause() }
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                    }
                } else {
                    Button {
                        Task { try await spotifyPlaybackManager.resume() }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                    }
                }
            }
            else {
                Button {
                    Task { @MainActor in
                        if !parentAudioTrackList.contents.isEmpty {
                            do {
                                try await spotifyPlaybackManager.play(audioTrack: parentAudioTrackList.contents[0])
                            } catch {
                                showAlertErrorStartPlayback = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: Musubi.UI.PLAY_SYMBOL_SIZE))
                }
            }
        }
        .alert(
            "Error when starting playback",
            isPresented: $showAlertErrorStartPlayback,
            actions: {},
            message: {
                Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
            }
        )
    }
}

//#Preview {
//    StaticArtistPage()
//}
