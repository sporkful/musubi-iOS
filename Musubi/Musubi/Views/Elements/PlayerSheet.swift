// PlayerSheet.swift

import SwiftUI

struct PlayerSheet: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    @Environment(\.openURL) private var openURL
    
    @Binding var showSheet: Bool
    
    @State private var coverImage: UIImage? = nil
    private var backgroundHighlightColor: UIColor { coverImage?.meanColor()?.muted() ?? .gray }
    
    @State private var isScrubbing = false
    @State private var sliderPositionMilliseconds: Double = SpotifyPlaybackManager.POSITION_MS_SLIDER_MIN
    
    @State private var isTitleMultiline = false
    @State private var isArtistsMultiline = false
    
    private enum CustomScrollPosition {
        case expandedArtistInfo
    }
    
    var body: some View {
        @Bindable var spotifyPlaybackManager = spotifyPlaybackManager
        
        ScrollViewReader { scrollProxy in
            ScrollView {
                if let currentTrack = spotifyPlaybackManager.currentTrack {
                    ZStack {
                        
                        // MARK: - hidden measurements
                        Text(currentTrack.audioTrack.name)
                            .font(.title2.leading(.tight))
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .lineLimit(1)
                            .hidden()
                            .background(
                                content: {
                                    ViewThatFits(in: .vertical) {
                                        Text(currentTrack.audioTrack.name)
                                            .font(.title2.leading(.tight))
                                            .fontWeight(.bold)
                                            .padding(.horizontal)
                                            .hidden()
                                            .onAppear {
                                                isTitleMultiline = false
                                            }
                                        Color.clear
                                            .hidden()
                                            .onAppear {
                                                isTitleMultiline = true
                                            }
                                    }
                                }
                            )
                        Text(currentTrack.audioTrack.artists.map { $0.name }.joined(separator: "   •   "))
                            .font(.subheadline)
                            .bold()
                            .padding(.horizontal)
                            .lineLimit(1)
                            .hidden()
                            .background(
                                content: {
                                    ViewThatFits(in: .vertical) {
                                        Text(currentTrack.audioTrack.artists.map { $0.name }.joined(separator: "   •   "))
                                            .font(.subheadline)
                                            .bold()
                                            .padding(.horizontal)
                                            .hidden()
                                            .onAppear {
                                                isArtistsMultiline = false
                                            }
                                        Color.clear
                                            .hidden()
                                            .onAppear {
                                                isArtistsMultiline = true
                                            }
                                    }
                                }
                            )
                        
                        // MARK: - visible view
                        
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(backgroundHighlightColor), location: 0),
                                Gradient.Stop(color: Color(backgroundHighlightColor), location: 0.420),
                                Gradient.Stop(color: .black, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: Musubi.UI.SCREEN_HEIGHT)
                        
                        VStack(alignment: .leading) {
                            HStack(alignment: .center) {
                                Button(
                                    action: { showSheet = false },
                                    label: {
                                        Image(systemName: "chevron.down")
                                            .frame(maxHeight: .infinity, alignment: .center)
                                    }
                                )
                                Spacer()
                                VStack(alignment: .center) {
                                    Text(currentTrack.parent?.context.type ?? "")
                                        .font(.caption)
                                        .lineLimit(1, reservesSpace: true)
                                    Text(currentTrack.parent?.context.name ?? "")
                                        .font(.subheadline)
                                        .bold()
                                        .lineLimit(2, reservesSpace: true)
                                        .multilineTextAlignment(.center)
                                }
                                .onTapGesture {
                                    openRelatedPage(audioTrackListContext: currentTrack.parent?.context)
                                }
                                Spacer()
                                SingleAudioTrackMenu(
                                    audioTrack: currentTrack,
                                    showParentSheet: $showSheet
                                )
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top)
                            Text("balancer")
                                .font(.title2.leading(.tight))
                                .fontWeight(.bold)
                                .hidden()
                            if let coverImage = coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .frame(height: min(Musubi.UI.SCREEN_WIDTH, Musubi.UI.SCREEN_HEIGHT) - 40)
                                    Spacer()
                                }
                            }
                            Text("\(isTitleMultiline ? "" : "\n")\(currentTrack.audioTrack.name)")
                                .font(.title2.leading(.tight))
                                .fontWeight(.bold)
                                .lineLimit(2, reservesSpace: true)
                                .multilineTextAlignment(.leading)
                                .padding(.top)
                            if !isArtistsMultiline {
                                HStack {
                                    ForEach(
                                        Array(zip(
                                            currentTrack.audioTrack.artists.indices,
                                            currentTrack.audioTrack.artists
                                        )),
                                        id: \.0
                                    ) { index, person in
                                        if index != 0 {
                                            Text("•")
                                                .font(.subheadline)
                                                .bold()
                                                .opacity(0.81)
                                        }
                                        Button(
                                            action: { openRelatedPage(spotifyNavigable: person) },
                                            label: {
                                                Text(person.name)
                                                    .font(.subheadline)
                                                    .bold()
                                                    .opacity(0.81)
                                                    .lineLimit(1)
                                            }
                                        )
                                    }
                                }
                                .padding(.bottom)
                            } else if !currentTrack.audioTrack.artists.isEmpty {
                                HStack {
                                    Button(
                                        action: { openRelatedPage(spotifyNavigable: currentTrack.audioTrack.artists.first!) },
                                        label: {
                                            Text(currentTrack.audioTrack.artists.first!.name)
                                                .font(.subheadline)
                                                .bold()
                                                .opacity(0.81)
                                                .lineLimit(1)
                                        }
                                    )
                                    if currentTrack.audioTrack.artists.count > 1 {
                                        Text("•")
                                            .font(.subheadline)
                                            .bold()
                                            .opacity(0.81)
                                        Button(
                                            action: {
                                                withAnimation {
                                                    scrollProxy.scrollTo(CustomScrollPosition.expandedArtistInfo)
                                                }
                                            },
                                            label: {
                                                Text("\(currentTrack.audioTrack.artists.count - 1) more")
                                                    .font(.subheadline)
                                                    .opacity(0.81)
                                                    .lineLimit(1)
                                            }
                                        )
                                    }
                                }
                                .padding(.bottom)
                            } else {
                                Text("placeholder")
                                    .font(.subheadline)
                                    .bold()
                                    .padding(.bottom)
                                    .hidden()
                            }
                            Slider(
                                value: isScrubbing ? $sliderPositionMilliseconds : $spotifyPlaybackManager.positionMilliseconds,
                                in: SpotifyPlaybackManager.POSITION_MS_SLIDER_MIN...Double(currentTrack.audioTrack.duration_ms),
                                label: {},
                                minimumValueLabel: {
                                    Text(stringify(milliseconds: isScrubbing ? sliderPositionMilliseconds : spotifyPlaybackManager.positionMilliseconds))
                                        .font(.caption)
                                        .opacity(0.81)
                                },
                                maximumValueLabel: {
                                    Text(stringify(milliseconds: Double(currentTrack.audioTrack.duration_ms)))
                                        .font(.caption)
                                        .opacity(0.81)
                                },
                                onEditingChanged: { newValue in
                                    if isScrubbing == true && newValue == false {
                                        Task {
                                            try await spotifyPlaybackManager.seek(toPositionMilliseconds: sliderPositionMilliseconds)
                                        }
                                    }
                                    isScrubbing = newValue
                                }
                            )
                            HStack(alignment: .center) {
                                Button {
                                    Task { try await spotifyPlaybackManager.toggleShuffle() }
                                } label: {
                                    Image(systemName: "shuffle")
                                        .font(.title2)
                                        .foregroundStyle(spotifyPlaybackManager.shuffle ? Color.green : Color.white.opacity(0.5))
                                }
                                Spacer()
                                Button {
                                    Task { try await spotifyPlaybackManager.skipToPrevious() }
                                } label: {
                                    Image(systemName: "backward.end.fill")
                                        .font(.title)
                                }
                                Spacer()
                                if spotifyPlaybackManager.isPlaying {
                                    Button {
                                        Task { try await spotifyPlaybackManager.pause() }
                                    } label: {
                                        Image(systemName: "pause.circle.fill")
                                            .font(.system(size: Musubi.UI.PrimaryPlayButtonSize.playerSheet.fontSize))
                                    }
                                } else {
                                    Button {
                                        Task { try await spotifyPlaybackManager.resume() }
                                    } label: {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: Musubi.UI.PrimaryPlayButtonSize.playerSheet.fontSize))
                                    }
                                }
                                Spacer()
                                Button {
                                    Task { try await spotifyPlaybackManager.skipToNext() }
                                } label: {
                                    Image(systemName: "forward.end.fill")
                                        .font(.title)
                                }
                                Spacer()
                                Button {
                                    Task { try await spotifyPlaybackManager.toggleRepeatState() }
                                } label: {
                                    if spotifyPlaybackManager.repeatState == .context {
                                        Image(systemName: "repeat")
                                            .font(.title2)
                                            .foregroundStyle(Color.green)
                                    } else if spotifyPlaybackManager.repeatState == .track {
                                        Image(systemName: "repeat.1")
                                            .font(.title2)
                                            .foregroundStyle(Color.green)
                                    } else {
                                        Image(systemName: "repeat")
                                            .font(.title2)
                                            .foregroundStyle(Color.white.opacity(0.5))
                                    }
                                }
                            }
                            HStack {
                                PlaybackDevicePicker(outerLabelStyle: .fullFootnote)
                                Spacer()
                                // TODO: queue?
                            }
                            .padding(.vertical)
                            VStack {
                                // TODO: expanded artist info
                            }
                            .id(CustomScrollPosition.expandedArtistInfo)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                } else {
                    ZStack {
                        Color.black
                            .frame(height: Musubi.UI.SCREEN_HEIGHT)
                        HStack {
                            Spacer()
                            Text("Something went wrong, please try again.")
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .background {
                VStack(spacing: 0) {
                    Color(backgroundHighlightColor)
                    Color.black
                }
            }
        }
        .onChange(of: spotifyPlaybackManager.currentTrack, initial: true) {
            loadCoverImage()
        }
        .interactiveDismissDisabled(false)
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
    }
    
    // TODO: better typing and error handling
    private func openRelatedPage(spotifyNavigable: any SpotifyNavigable) {
        Task { @MainActor in
            showSheet = false
            try await homeViewCoordinator.openSpotifyNavigable(spotifyNavigable)
        }
    }
    
    private func openRelatedPage(audioTrackListContext: AudioTrackListContext?) {
        if let context = audioTrackListContext {
            if let spotifyNavigableContext = context as? any SpotifyNavigable {
                openRelatedPage(spotifyNavigable: spotifyNavigableContext)
            } else if let musubiNavigableContext = context as? any MusubiNavigable {
                Task { @MainActor in
                    showSheet = false
                    try await homeViewCoordinator.openMusubiNavigable(musubiNavigableContext)
                }
            }
        }
    }
    
    private func loadCoverImage() {
        Musubi.Retry.run(
            failableAction: {
                guard let coverImageURLString = await spotifyPlaybackManager.currentTrack?.audioTrack.album?.coverImageURLString,
                      let coverImageURL = URL(string: coverImageURLString)
                else {
                    return
                }
                
                self.coverImage = try await SpotifyRequests.Read.image(url: coverImageURL)
            }
        )
    }
    
    private func stringify(milliseconds: Double) -> String {
        let seconds: Int = Int(milliseconds / 1000) % 60
        let minutes: Int = Int(milliseconds / (1000 * 60))
        return String(format:"%d:%02d", minutes, seconds)
    }
}

//#Preview {
//    PlayerSheet()
//}
