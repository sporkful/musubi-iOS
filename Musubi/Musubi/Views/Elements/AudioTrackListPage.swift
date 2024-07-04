// AudioTrackListPage.swift

import SwiftUI

// TODO: fix glitchy tabbar when going Search -> Track -> View Album
// TODO: use Labels to construct CustomToolbarItems (and elsewhere)

struct AudioTrackListPage: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    @Binding var navigationPath: NavigationPath
    
    // TODO: is @Bindable necessary?
    @Bindable var audioTrackList: Musubi.ViewModel.AudioTrackList
    
    let showAudioTrackThumbnails: Bool
    
    let customToolbarAdditionalItems: [CustomToolbarItem]
    
    struct CustomToolbarItem: Hashable {
        let title: String
        let sfSymbolName: String
        let action: () -> Void
        var isDisabledVisually: Bool = false
        
        static func == (lhs: AudioTrackListPage.CustomToolbarItem, rhs: AudioTrackListPage.CustomToolbarItem) -> Bool {
            return lhs.title == rhs.title
                && lhs.sfSymbolName == rhs.sfSymbolName
                && lhs.isDisabledVisually == rhs.isDisabledVisually
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(sfSymbolName)
            hasher.combine(isDisabledVisually)
        }
    }
    
    @State private var showSheetAddToSelectableClones = false
    
    @State private var showAlertErrorRehydration = false
    
    @State private var coverImage: UIImage?
    
    private let COVER_IMAGE_INITIAL_DIMENSION = Musubi.UI.ImageDimension.audioTracklistCover.rawValue
    private let COVER_IMAGE_SHADOW_RADIUS: CGFloat = 5
    private let TITLE_TEXT_HEIGHT: CGFloat = 42
    private let NAVBAR_OFFSET: CGFloat = 52
    private let PLAY_SYMBOL_SIZE = Musubi.UI.PLAY_SYMBOL_SIZE
    
    private var backgroundHighlightColor: UIColor { coverImage?.meanColor()?.muted() ?? .black }
    
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
            y1: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 4.20 + PLAY_SYMBOL_SIZE * 1.88 + NAVBAR_OFFSET,
            x2: COVER_IMAGE_INITIAL_DIMENSION,
            y2: TITLE_TEXT_HEIGHT * 3.30 + NAVBAR_OFFSET,
            minY: 1.0,
            maxY: COVER_IMAGE_INITIAL_DIMENSION + TITLE_TEXT_HEIGHT * 4.20 + PLAY_SYMBOL_SIZE * 1.88 + NAVBAR_OFFSET
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
            VStack(alignment: .center) {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(backgroundHighlightColor), location: 0),
                        Gradient.Stop(color: Color(backgroundHighlightColor), location: 0.330),
                        Gradient.Stop(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: gradientDimension)
                .opacity(gradientOpacity)
            }
            .ignoresSafeArea(.all, edges: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            VStack(alignment: .center) {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: coverImageDimension, height: coverImageDimension)
                        .clipped()
                        .shadow(color: .black, radius: COVER_IMAGE_SHADOW_RADIUS)
                        .opacity(coverImageOpacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ScrollView {
                LazyVStack(alignment: .leading) {
                    if coverImage != nil {
                        Rectangle()
                            .frame(height: COVER_IMAGE_INITIAL_DIMENSION)
                            .hidden()
                    }
                    Text(audioTrackList.context.name)
                        .font(.title.leading(.tight))
                        .fontWeight(.bold)
                    if let formattedDescription = audioTrackList.context.formattedDescription {
                        Text(formattedDescription)
                            .font(.caption)
                    }
                    HStack {
                        ForEach(
                            Array(
                                zip(
                                    audioTrackList.context.associatedPeople.indices,
                                    audioTrackList.context.associatedPeople
                                )
                            ),
                            id: \.0
                        ) { index, person in
                            if index != 0 {
                                Text("•")
                            }
                            Button {
                                navigationPath.append(person)
                            } label: {
                                Text(person.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    Text(audioTrackList.context.type)
                        .font(.caption)
                    if let associatedDate = audioTrackList.context.associatedDate {
                        Text(associatedDate)
                            .font(.caption)
                    }
                    CustomToolbar(
                        customToolbarAdditionalItems: customToolbarAdditionalItems,
                        parentAudioTrackList: audioTrackList,
                        showSheetAddToSelectableClones: $showSheetAddToSelectableClones
                    )
                    ForEach(audioTrackList.contents, id: \.self) { audioTrack in
                        Divider()
                        ListCellWrapper(
                            item: audioTrack,
                            showThumbnail: showAudioTrackThumbnails,
                            customTextStyle: .defaultStyle,
                            showAudioTrackMenu: true
                        )
                    }
                    if spotifyPlaybackManager.currentTrack != nil {
                        Rectangle()
                            .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                            .padding(6.30 + 3.30)
                            .hidden()
                    }
                }
                .padding([.horizontal, .bottom])
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
                    Text(audioTrackList.context.name)
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
        .onChange(of: audioTrackList.context.coverImageURLString, initial: true) {
            loadCoverImage()
        }
        .sheet(isPresented: $showSheetAddToSelectableClones) {
            AddToSelectableLocalClonesSheet(
                showSheet: $showSheetAddToSelectableClones,
                audioTrackList: audioTrackList
            )
        }
        .onAppear(perform: rehydrateIfNeeded)
        .alert(
            "Error when refreshing contents",
            isPresented: $showAlertErrorRehydration,
            actions: {
                Button("OK", action: { navigationPath.removeLast() } )
            },
            message: {
                Text(Musubi.UI.ErrorMessage(suggestedFix: .contactDev).string)
            }
        )
    }
    
    // TODO: better regulation of when this is called, e.g. user swipe up to reload?
    // TODO: refresh metadata as well?
    private func rehydrateIfNeeded() {
        Task {
            guard let contextPlaylist = audioTrackList.context as? Spotify.PlaylistMetadata else {
                // All other contexts are either relatively static or maintained locally.
                return
            }
            print("[Musubi::AudioTrackListPage] rehydrateIfNeeded on remote playlist")
            
            do {
                try await audioTrackList.refreshContentsIfNeeded(
                    newContents: SpotifyRequests.Read.playlistTrackListFull(playlistID: contextPlaylist.id)
                )
            } catch {
                print("[Musubi::AudioTrackListPage] failed to complete rehydrateIfNeeded")
                print(error.localizedDescription)
                showAlertErrorRehydration = true
            }
        }
    }
    
    // TODO: share logic with RetryableAsyncImage?
    private func loadCoverImage() {
        guard let coverImageURLString = audioTrackList.context.coverImageURLString,
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
    
    struct CustomToolbar: View {
        @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
        
        let customToolbarAdditionalItems: [CustomToolbarItem]
        
        // TODO: is @Bindable necessary?
        @Bindable var parentAudioTrackList: Musubi.ViewModel.AudioTrackList
        
        @Binding var showSheetAddToSelectableClones: Bool
        
        @State private var showAlertErrorStartPlayback = false
        
        var body: some View {
            HStack {
                ForEach(customToolbarAdditionalItems, id: \.self) { customToolbarItem in
                if !customToolbarItem.isDisabledVisually {
                    Button {
                        customToolbarItem.action()
                    } label: {
                        Image(systemName: customToolbarItem.sfSymbolName)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button {
                    } label: {
                        Image(systemName: customToolbarItem.sfSymbolName)
                            .contentShape(Rectangle())
                    }
                    .disabled(true)
                    .onTapGesture(perform: customToolbarItem.action)
                }
                }
                Menu {
                    Button {
                        showSheetAddToSelectableClones = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add tracks from this collection to")
                        }
                    }
                    ForEach(customToolbarAdditionalItems, id: \.self) { customToolbarItem in
                    if !customToolbarItem.isDisabledVisually {
                        Button {
                            customToolbarItem.action()
                        } label: {
                            Label(customToolbarItem.title, systemImage: customToolbarItem.sfSymbolName)
                        }
                    } else {
                        Button {
                        } label: {
                            Label(customToolbarItem.title, systemImage: customToolbarItem.sfSymbolName)
                        }
                        .disabled(true)
                        .onTapGesture(perform: customToolbarItem.action)
                    }
                    }
                } label: {
                    Image(systemName: "ellipsis")
//                        .font(.system(size: Musubi.UI.MENU_SYMBOL_SIZE))
//                        .frame(height: Musubi.UI.MENU_SYMBOL_SIZE)
                        .contentShape(Rectangle())
                }
                Spacer()
                // TODO: Spotify's shuffle button here is persistently tied to the specific tracklist open
//                Button {
//                    Task { try await spotifyPlaybackManager.toggleShuffle() }
//                } label: {
//                    Image(systemName: "shuffle")
//                        .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
//                        .foregroundStyle(spotifyPlaybackManager.shuffle ? Color.green : Color.white.opacity(0.5))
//                }
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
}


//#Preview {
//    AudioTrackListPage()
//}
