// AlbumStaticPageView.swift

import SwiftUI

struct AlbumStaticPageView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    let album: Spotify.Model.Album
    
    @Binding var navigationPath: NavigationPath
    
    @State private var audioTrackList: [Spotify.Model.AudioTrack] = []
    
    @State private var image: UIImage?
    private let ALBUM_COVER_DIM = Musubi.UIConstants.ImageDimension.albumCover.rawValue
    
    private var backgroundHighlightColor: UIColor {
        image?.musubi_DominantColor()?.musubi_Muted() ?? .black
    }
    
    private let IMAGE_SHADOW_RADIUS = Musubi.UIConstants.IMAGE_SHADOW_RADIUS
    private let SCROLLVIEW_BACKGROUND_CUTOFF = Musubi.UIConstants.SCROLLVIEW_BACKGROUND_CUTOFF
    
    private let SCROLLVIEW_IMAGE_BOTTOM_Y = Musubi.UIConstants.SCROLLVIEW_IMAGE_BOTTOM_Y
    private let SCROLLVIEW_TITLE_HEIGHT = Musubi.UIConstants.SCROLLVIEW_TITLE_HEIGHT
    private let SCROLLVIEW_TITLE_SAT_POINT = Musubi.UIConstants.SCROLLVIEW_TITLE_SAT_POINT
    
    // remember scrollPosition=0 at top and increases as user scrolls down.
    @State private var scrollPosition: CGFloat = 0
    private var isScrollBelowCover: Bool {
        scrollPosition > SCROLLVIEW_IMAGE_BOTTOM_Y
    }
    private var navigationTitleOpacity: Double {
        // lerp between
        //  (~SCROLLVIEW_IMAGE_BOTTOM_Y, 0.0) and
        //  (~SCROLLVIEW_IMAGE_BOTTOM_Y + SCROLLVIEW_TITLE_HEIGHT * SCROLLVIEW_TITLE_SAT_POINT, 1.0)
        let unclamped = (scrollPosition - (SCROLLVIEW_IMAGE_BOTTOM_Y + 5))
            / (SCROLLVIEW_TITLE_HEIGHT * SCROLLVIEW_TITLE_SAT_POINT)
        return min(max(unclamped, 0), 1)
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
                        if let image = image {
                            HStack {
                                Spacer()
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                                    .frame(width: ALBUM_COVER_DIM, height: ALBUM_COVER_DIM)
                                    .shadow(radius: IMAGE_SHADOW_RADIUS)
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
            guard let imageURLString = self.album.images?.first?.url,
                  let imageURL = URL(string: imageURLString)
            else {
                throw Musubi.UIError.any(detail: "AlbumStaticPageView no image url found")
            }
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            self.image = UIImage(data: imageData)
        } catch {
            print("[Musubi::AlbumStaticPageView] unable to load image")
            print(error)
        }
    }
}

//#Preview {
//    AlbumStaticPageView()
//}
