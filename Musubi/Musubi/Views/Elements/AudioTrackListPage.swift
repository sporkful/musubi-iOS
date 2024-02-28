// AudioTrackListPage.swift

import SwiftUI

struct AudioTrackListPage: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @Binding var navigationPath: NavigationPath
    
    enum ContentType: String {
        case album = "Album"
        case playlist = "Playlist"
    }
    
    let contentType: ContentType
    let isEditable: Bool
    
    @Binding var name: String
    @Binding var coverImage: UIImage?
    @Binding var audioTrackList: [Spotify.Model.AudioTrack]
    
    enum AssociatedPeople {
        case artists([Spotify.Model.Artist])
        case users([Spotify.Model.OtherUser])
    }
    let associatedPeople: AssociatedPeople
    let date: String
    
    
    private let COVER_IMAGE_INITIAL_DIMENSION = Musubi.UI.ImageDimension.audioTracklistCover.rawValue
    private let COVER_IMAGE_SHADOW_RADIUS = Musubi.UI.COVER_IMAGE_SHADOW_RADIUS
    
    private var backgroundHighlightColor: UIColor {
        coverImage?.musubi_DominantColor()?.musubi_Muted() ?? .black
    }
    
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
            y1: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 2.62,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: TITLE_TEXT_HEIGHT * 3.30,
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
                    Text(name)
                        .font(.title)
                        .fontWeight(.bold)
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
                    Text("\(contentType.rawValue) • \(date)")
                        .font(.caption)
                    HStack {
                        // TODO: finish
                        if isEditable {
                            Button {
                                // TODO: show sheet
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            Button {
                                // TODO: show sheet or push onto navstack?
                            } label: {
                                Image(systemName: "clock.arrow.2.circlepath")
                            }
                        }
                        Menu {
                            if isEditable {
                                Button {
                                    // TODO: show sheet
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.pencil")
                                        Text("Edit")
                                    }
                                }
                                Button {
                                    // TODO: show sheet or push onto navstack?
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.2.circlepath")
                                        Text("Version control")
                                    }
                                }
                            }
                            Button {
                                // TODO: impl
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add all tracks in this collection to playlist")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: MENU_SYMBOL_SIZE))
                                .frame(height: MENU_SYMBOL_SIZE)
                                .contentShape(Rectangle())
                        }
                        Spacer()
                        Button {
                            // TODO: impl
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: SHUFFLE_SYMBOL_SIZE))
                            // TODO: opacity depending on toggle state
                        }
                        Button {
                            // TODO: impl
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: PLAY_SYMBOL_SIZE))
                        }
                    }
                    ForEach($audioTrackList) { $audioTrack in
                        Divider()
                        AudioTrackListCell(audioTrack: audioTrack, navigationPath: $navigationPath)
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
    }
}

//#Preview {
//    AudioTrackListPage()
//}
