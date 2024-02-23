// AlbumStaticPageView.swift

import SwiftUI

struct AlbumStaticPageView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    let album: Spotify.Model.Album
    
    @Binding var navigationPath: NavigationPath
    
    @State private var audioTrackList: [Spotify.Model.AudioTrack] = []
    
    @State private var coverImage: UIImage?
    private let COVER_IMAGE_INITIAL_DIMENSION = Musubi.UI.ImageDimension.audioTracklistCover.rawValue
    private let COVER_IMAGE_SHADOW_RADIUS = Musubi.UI.COVER_IMAGE_SHADOW_RADIUS
    
    private var backgroundHighlightColor: UIColor {
        coverImage?.musubi_DominantColor()?.musubi_Muted() ?? .black
    }
    
    // remember scrollPosition=0 at top and increases as user scrolls down.
    @State private var scrollPosition: CGFloat = 0
    private var coverImageDimension: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: 0.0,
            y1: COVER_IMAGE_INITIAL_DIMENSION,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: COVER_IMAGE_INITIAL_DIMENSION * 0.5,
            minY: 0.0,
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
            y1: COVER_IMAGE_INITIAL_DIMENSION + SCROLLVIEW_TITLE_HEIGHT * 2.62,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: SCROLLVIEW_TITLE_HEIGHT * 3.30,
            minY: 1.0,
            maxY: Musubi.UI.SCREEN_HEIGHT
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
    
    private let SCROLLVIEW_TITLE_HEIGHT = Musubi.UI.SCROLLVIEW_TITLE_HEIGHT
    private let SCROLLVIEW_TITLE_SAT_POINT = Musubi.UI.SCROLLVIEW_TITLE_SAT_POINT
    private var navTitleOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_INITIAL_DIMENSION + SCROLLVIEW_TITLE_HEIGHT * 0.420,
            y1: 0.0,
            x2: COVER_IMAGE_INITIAL_DIMENSION + SCROLLVIEW_TITLE_HEIGHT * 2.62,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var navBarOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
//            x1: COVER_IMAGE_INITIAL_DIMENSION - SCROLLVIEW_TITLE_HEIGHT * SCROLLVIEW_TITLE_SAT_POINT,
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
                        .aspectRatio(contentMode: .fit)
                        .frame(height: coverImageDimension)
//                        .clipped()
                        .shadow(radius: COVER_IMAGE_SHADOW_RADIUS)
                        .opacity(coverImageOpacity)
                }
                Spacer()
            }
            .ignoresSafeArea(.all, edges: [.horizontal])
            ScrollView {
                VStack(alignment: .leading) {
                    if coverImage != nil {
                        Rectangle()
                            .frame(height: COVER_IMAGE_INITIAL_DIMENSION)
                            .hidden()
                    }
                    Text(album.name)
                        .font(.title)
                        .fontWeight(.bold)
                    HStack {
                        ForEach(Array(zip(album.artists.indices, album.artists)), id: \.0) { index, artist in
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
                    }
                    Text("Album • \(album.release_date)")
                        .font(.caption)
                    ForEach(audioTrackList) { audioTrack in
                        Divider()
                        AudioTrackListCellView(audioTrack: audioTrack, navigationPath: $navigationPath)
                    }
                }
                .padding([.horizontal, .bottom])
                .background(
                    GeometryReader { proxy -> Color in
                        Task { @MainActor in
                            scrollPosition = -proxy
                                .frame(in: .named("AlbumStaticPageView::ScrollView"))
                                .origin.y
                            print("scroll position \(scrollPosition)")
                        }
                        return Color.clear
                    }
                )
            }
            .ignoresSafeArea(.all, edges: [.horizontal])
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "AlbumStaticPageView::ScrollView")
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
                    Text(album.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(navTitleOpacity)
                    Spacer()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // TODO: remove
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("PLACEHOLDER")
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.2.circlepath")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadContents()
        }
    }
    
    @MainActor
    func loadContents() async {
        do {
            self.audioTrackList = try await Spotify.Requests.Read.albumTracklist(
                albumID: album.id,
                userManager: userManager
            )
        } catch {
            // TODO: alert user?
            print("[Musubi::AlbumStaticPageView] unable to load tracklist")
            print(error)
        }
        
        do {
            guard let coverImageURLStr = self.album.images?.first?.url,
                  let coverImageURL = URL(string: coverImageURLStr)
            else {
                throw Musubi.UIError.any(detail: "AlbumStaticPageView no image url found")
            }
            let (imageData, _) = try await URLSession.shared.data(from: coverImageURL)
            self.coverImage = UIImage(data: imageData)
        } catch {
            print("[Musubi::AlbumStaticPageView] unable to load cover image")
            print(error)
        }
    }
}

//#Preview {
//    AlbumStaticPageView()
//}
