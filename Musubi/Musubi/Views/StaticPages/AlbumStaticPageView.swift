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
    
    private let SCROLLVIEW_COVER_BOTTOM_Y = Musubi.UI.SCROLLVIEW_COVER_BOTTOM_Y
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
            maxY: COVER_IMAGE_DIM
        )
    }
    private var coverImageOpacity: CGFloat {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: COVER_IMAGE_DIM / 2,
            y1: 1.0,
            x2: COVER_IMAGE_DIM,
            y2: 0.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    private var isScrollBelowCover: Bool {
        scrollPosition > SCROLLVIEW_COVER_BOTTOM_Y
    }
    private var navigationTitleOpacity: Double {
        return Musubi.UI.lerp(
            x: scrollPosition,
            x1: SCROLLVIEW_COVER_BOTTOM_Y + 5,
            y1: 0.0,
            x2: SCROLLVIEW_COVER_BOTTOM_Y + SCROLLVIEW_TITLE_HEIGHT * SCROLLVIEW_TITLE_SAT_POINT,
            y2: 1.0,
            minY: 0.0,
            maxY: 1.0
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(backgroundHighlightColor),
                            .black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading) {
                        if let image = coverImage {
                            HStack {
                                Spacer()
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                                    .frame(width: COVER_IMAGE_DIM, height: COVER_IMAGE_DIM)
                                    .shadow(radius: COVER_IMAGE_SHADOW_RADIUS)
                                Spacer()
                            }
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
                    }
                    .padding([.horizontal])
                }
                VStack {
                    ForEach(audioTrackList) { audioTrack in
                        Divider()
                        AudioTrackListCellView(audioTrack: audioTrack, navigationPath: $navigationPath)
                    }
                    Spacer()
                }
                .padding([.horizontal, .bottom])
            }
            .background(
                GeometryReader { proxy -> Color in
                    DispatchQueue.main.async {
                        scrollPosition = -proxy
                            .frame(in: .named("AlbumStaticPageView::ScrollView"))
                            .origin.y
                        print("scroll position \(scrollPosition)")
                    }
                    return Color.black
                }
            )
        }
        .ignoresSafeArea(.all, edges: [.horizontal])
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(backgroundHighlightColor), location: SCROLLVIEW_BACKGROUND_CUTOFF),
                    .init(color: .black, location: SCROLLVIEW_BACKGROUND_CUTOFF + 0.01)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .scrollContentBackground(.hidden)
        .coordinateSpace(name: "AlbumStaticPageView::ScrollView")
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
