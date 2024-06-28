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
                            }
                        )
                        Spacer()
                        // TODO: make tappable / automate nav
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
                        Spacer()
                        SingleAudioTrackMenu(
                            audioTrack: currentTrack,
                            showParentSheet: $showSheet
                        )
                    }
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
                                .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                                .foregroundStyle(spotifyPlaybackManager.shuffle ? Color.green : Color.white.opacity(0.5))
                        }
                        Spacer()
                        Button {
                            Task { try await spotifyPlaybackManager.skipToPrevious() }
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                        }
                        Spacer()
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
                        Spacer()
                        Button {
                            Task { try await spotifyPlaybackManager.skipToNext() }
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                        }
                        Spacer()
                        Button {
                            Task { try await spotifyPlaybackManager.toggleRepeatState() }
                        } label: {
                            if spotifyPlaybackManager.repeatState == .context {
                                Image(systemName: "repeat")
                                    .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                                    .foregroundStyle(Color.green)
                            } else if spotifyPlaybackManager.repeatState == .track {
                                Image(systemName: "repeat.1")
                                    .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
                                    .foregroundStyle(Color.green)
                            } else {
                                Image(systemName: "repeat")
                                    .font(.system(size: Musubi.UI.SHUFFLE_SYMBOL_SIZE))
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
            "Error when starting playback",
            isPresented: $spotifyPlaybackManager.showAlertNoDevice,
            actions: {},
            message: {
                Text(spotifyPlaybackManager.NO_DEVICE_ERROR_MESSAGE)
            }
        )
        .alert(
            "Please open the official Spotify app to complete your action",
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
    
    // TODO: consolidate in HomeViewCoordinator
    // TODO: activity indicator / disableUI
    // TODO: better typing
    private func openRelatedPage(spotifyNavigable: any SpotifyNavigable) {
        Task { @MainActor in
            showSheet = false
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            if homeViewCoordinator.openTab != .spotifySearch {
                homeViewCoordinator.openTab = .spotifySearch
                try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            }
            homeViewCoordinator.spotifySearchNavPath.append(spotifyNavigable)
        }
    }
    
    // TODO: share logic with RetryableAsyncImage?
    private func loadCoverImage() {
        Task { @MainActor in
            while true {
                if let coverImageURLString = spotifyPlaybackManager.currentTrack?.audioTrack.coverImageURLString,
                   let coverImageURL = URL(string: coverImageURLString),
                   let coverImage = try? await SpotifyRequests.Read.image(url: coverImageURL)
                {
                    self.coverImage = coverImage
                    return
                }
                do {
                    try await Task.sleep(until: .now + .seconds(3), clock: .continuous)
                } catch {
                    return // task was cancelled
                }
            }
        }
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
