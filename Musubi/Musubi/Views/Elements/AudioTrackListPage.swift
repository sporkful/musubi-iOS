// AudioTrackListPage.swift

import SwiftUI

// TODO: fix bouncing at top and bottom edges

struct AudioTrackListPage<CustomToolbar: View>: View {    
    @Binding var navigationPath: NavigationPath
    
    enum ContentType: String {
        case album = "Album"
        case spotifyPlaylist = "Spotify Playlist"
        case musubiLocalClone = "Musubi Local Clone"
    }
    
    let contentType: ContentType
    
    @Binding var name: String
    @Binding var description: String
    @Binding var coverImageURLString: String?
    
    @Binding var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    enum AssociatedPeople {
        case artists([Spotify.Artist])
        case users([Spotify.OtherUser])
    }
    let associatedPeople: AssociatedPeople
    let date: String
    
    let toolbarBuilder: () -> CustomToolbar
    
    
    @State private var coverImage: UIImage?
    
    private let COVER_IMAGE_INITIAL_DIMENSION = Musubi.UI.ImageDimension.audioTracklistCover.rawValue
    private let COVER_IMAGE_SHADOW_RADIUS = Musubi.UI.COVER_IMAGE_SHADOW_RADIUS
    
    private var backgroundHighlightColor: UIColor { coverImage?.meanColor()?.muted() ?? .black }
    
    private let PLAY_SYMBOL_SIZE = Musubi.UI.PLAY_SYMBOL_SIZE
    private let SHUFFLE_SYMBOL_SIZE = Musubi.UI.SHUFFLE_SYMBOL_SIZE
    private let MENU_SYMBOL_SIZE = Musubi.UI.MENU_SYMBOL_SIZE
    
    private let viewID = UUID() // for scroll view coordinate space id
    
    // remember scrollPosition=0 at top and increases as user scrolls down.
    @State private var scrollPosition: CGFloat = 0
    private var coverImageDimension: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: 0.0,
            y1: COVER_IMAGE_INITIAL_DIMENSION,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: COVER_IMAGE_INITIAL_DIMENSION * 0.5,
            minY: COVER_IMAGE_INITIAL_DIMENSION * 0.25, // has faded away at this point
            maxY: Musubi.UI.SCREEN_WIDTH
        )
    }
    private var coverImageOpacity: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION * 0.1,
            y1: 1.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION * 0.75,
            y2: 0.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    
    private var gradientDimension: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: 0.0,
            y1: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 4.20 + PLAY_SYMBOL_SIZE * 1.88,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: TITLE_TEXT_HEIGHT * 3.30,
            minY: 1.0,
            maxY: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 4.20 + PLAY_SYMBOL_SIZE * 1.88
        )
    }
    private var gradientOpacity: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION * 0.1,
            y1: 1.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: 0.824,
            minY: 0.824,
            maxY: 1.0
        )
    }
    
    private let TITLE_TEXT_HEIGHT = Musubi.UI.TITLE_TEXT_HEIGHT
    private var navTitleOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 0.420,
            y1: 0.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 2.62,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var navBarOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION * 0.75,
            y1: 0.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    
    var body: some View {
        ZStack {
            VStack {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(backgroundHighlightColor), location: 0),
                        Gradient.Stop(color: Color(backgroundHighlightColor), location: 0.330),
                        Gradient.Stop(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // TODO: this seems unreliable
                // Note behavior changes depending on order of the following two modifiers.
                // By calling frame after, we don't need to add any offset for safe area / navbar.
                .ignoresSafeArea(.all, edges: [.horizontal, .top])
                .frame(height: gradientDimension)
                .opacity(gradientOpacity)
                Spacer()
            }
            VStack {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: coverImageDimension, height: coverImageDimension)
                        .clipped()
                        .shadow(radius: COVER_IMAGE_SHADOW_RADIUS)
                        .opacity(coverImageOpacity)
                }
                Spacer()
            }
            .ignoresSafeArea(.all, edges: [.horizontal])
            ScrollView {
                LazyVStack(alignment: .leading) {
                    if coverImage != nil {
                        Rectangle()
                            .frame(height: COVER_IMAGE_INITIAL_DIMENSION)
                            .hidden()
                    }
                    Text(name)
                        .font(.title)
                        .fontWeight(.bold)
                    if !description.isEmpty {
                        Text(description)
                            .font(.caption)
                    }
                    HStack {
                        // TODO: fix repetition here somehow without turning into ViewBuilder
                        switch associatedPeople {
                        case .artists(let artists):
                            ForEach(Array(zip(artists.indices, artists)), id: \.0) { index, artist in
                                if index != 0 {
                                    Text("•")
                                }
                                Button {
                                    navigationPath.append(artist)
                                } label: {
                                    Text(artist.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                            }
                        case .users(let users):
                            ForEach(Array(zip(users.indices, users)), id: \.0) { index, user in
                                if index != 0 {
                                    Text("•")
                                }
                                Button {
                                    navigationPath.append(user)
                                } label: {
                                    Text(user.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                    Text(contentType.rawValue)
                        .font(.caption)
                    switch contentType {
                    case .album:
                        if !date.isEmpty {
                            Text("Release Date: \(date)")
                                .font(.caption)
                        }
                    case .musubiLocalClone:
                        VStack {}  // TODO: last updated date?
                    case .spotifyPlaylist:
                        VStack {}
                    }
                    toolbarBuilder()
                    ForEach($audioTrackList) { $item in
                        Divider()
                        AudioTrackListCell(audioTrack: item.audioTrack, navigationPath: $navigationPath)
                    }
                }
                .padding([.horizontal, .bottom])
                .background(
                    GeometryReader { proxy -> Color in
                        Task { @MainActor in
                            scrollPosition = -proxy
                                .frame(in: .named("\(viewID.uuidString)::ScrollView"))
                                .origin.y
//                            print("scroll position \(scrollPosition)")
                        }
                        return Color.clear
                    }
                )
            }
            .ignoresSafeArea(.all, edges: [.horizontal])
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "\(viewID.uuidString)::ScrollView")
            VStack {
                Color(backgroundHighlightColor)
                    // TODO: this seems unreliable
                    // Note behavior changes depending on order of the following two modifiers.
                    // By calling frame after, we don't need to add any offset for safe area / navbar.
                    .ignoresSafeArea(.all, edges: [.horizontal, .top])
                    .frame(height: 1)
                    .opacity(0.420)
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
                    Text(name)
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
        .onChange(of: coverImageURLString, initial: true) {
            loadCoverImage()
        }
    }
    
    // TODO: share logic with RetryableAsyncImage?
    private func loadCoverImage() {
        guard let coverImageURLString = coverImageURLString,
              let coverImageURL = URL(string: coverImageURLString)
        else {
            return
        }
        
        Task { @MainActor in
            if let (data, response) = try? await URLSession.shared.data(from: coverImageURL),
               let httpResponse = response as? HTTPURLResponse,
               SpotifyConstants.HTTP_SUCCESS_CODES.contains(httpResponse.statusCode)
            {
                coverImage = UIImage(data: data)
            }
        }
    }
}

//#Preview {
//    AudioTrackListPage()
//}
