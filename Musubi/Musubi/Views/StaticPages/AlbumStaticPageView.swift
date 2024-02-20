// AlbumStaticPageView.swift

import SwiftUI

struct AlbumStaticPageView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    let album: Spotify.Model.Album
    
    @Binding var navigationPath: NavigationPath
    
    @State private var audioTrackList: [Spotify.Model.AudioTrack] = []
    
    @State private var coverImage: UIImage?
    private let COVER_IMAGE_DIM = Musubi.UI.ImageDimension.audioTracklistCover.rawValue
    
    private var backgroundHighlightColor: UIColor {
        coverImage?.musubi_DominantColor()?.musubi_Muted() ?? .black
    }
    
    private let COVER_IMAGE_SHADOW_RADIUS = Musubi.UI.COVER_IMAGE_SHADOW_RADIUS
    private let SCROLLVIEW_BACKGROUND_CUTOFF = Musubi.UI.SCROLLVIEW_BACKGROUND_CUTOFF
    
    private let SCROLLVIEW_TITLE_HEIGHT = Musubi.UI.SCROLLVIEW_TITLE_HEIGHT
    private let SCROLLVIEW_TITLE_SAT_POINT = Musubi.UI.SCROLLVIEW_TITLE_SAT_POINT
    
    // remember scrollPosition=0 at top and increases as user scrolls down.
    @State private var scrollPosition: CGFloat = 0
    private var coverImageDimension: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: 0.0,
            y1: COVER_IMAGE_DIM,
            x2: COVER_IMAGE_DIM,
            y2: 0.0,
            minY: 0.0,
            maxY: Musubi.UI.SCREEN_WIDTH
        )
    }
    private var coverImageOpacity: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_DIM / 4,
            y1: 1.0,
            x2: COVER_IMAGE_DIM / 2,
            y2: 0.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var isScrollBelowCover: Bool {
        scrollPosition > coverImageDimension
    }
    private var navigationTitleOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: coverImageDimension + 5,
            y1: 0.0,
            x2: coverImageDimension + SCROLLVIEW_TITLE_HEIGHT * SCROLLVIEW_TITLE_SAT_POINT,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(backgroundHighlightColor),
                    .black
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: coverImageDimension / Musubi.UI.SCREEN_HEIGHT)
            )
            .ignoresSafeArea(.all, edges: [.horizontal, .top])
            VStack {
                if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
//                            .scaledToFill()
//                            .clipped()
//                            .frame(width: coverImageDimension, height: coverImageDimension)
                            .frame(height: coverImageDimension)
                            .shadow(radius: COVER_IMAGE_SHADOW_RADIUS)
                            .opacity(coverImageOpacity)
                }
                Spacer()
            }
            .ignoresSafeArea(.all, edges: [.horizontal])
            ScrollView {
                VStack(alignment: .leading) {
                    if let image = coverImage {
                        Rectangle()
                            .frame(height: coverImageDimension)
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
                                    .foregroundColor(.white)
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(album.name)
                    .font(.headline)
                    .opacity(navigationTitleOpacity)
            }
        }
        .toolbarBackground(isScrollBelowCover ? .automatic : .hidden, for: .navigationBar)
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
