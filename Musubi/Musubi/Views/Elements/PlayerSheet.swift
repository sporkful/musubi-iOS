// PlayerSheet.swift

import SwiftUI

struct PlayerSheet: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @Binding var showSheet: Bool
    
    @State private var coverImage: UIImage? = nil
    private var backgroundHighlightColor: UIColor { coverImage?.meanColor()?.muted() ?? .gray }
    let COVER_IMAGE_SIZE = Musubi.UI.ImageDimension.playerCover.rawValue
    
    @State private var isScrubbing = false
    @State private var sliderPositionMilliseconds: Double = SpotifyPlaybackManager.POSITION_MS_SLIDER_MIN
    
    var body: some View {
        @Bindable var spotifyPlaybackManager = spotifyPlaybackManager
        
        ScrollView {
            if let currentTrack = spotifyPlaybackManager.currentTrack {
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
                            Text("Current Playback Context")
                                .font(.caption2)
                                .opacity(0.81)
                            Text(currentTrack.parent?.context.type ?? "Single Track")
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
                    .padding()
                    HStack {
                        Spacer()
                        if let coverImage = coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: COVER_IMAGE_SIZE, height: COVER_IMAGE_SIZE)
                                .clipped()
                        } else {
                            ProgressView()
                                .frame(width: COVER_IMAGE_SIZE, height: COVER_IMAGE_SIZE)
                        }
                        Spacer()
                    }
                    Text(currentTrack.audioTrack.name)
                        .font(.title2.leading(.tight))
                        .fontWeight(.bold)
                        .padding(.horizontal)
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
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
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
                    .padding(.horizontal)
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
                    .padding(.horizontal)
                }
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color(backgroundHighlightColor), location: 0),
                            Gradient.Stop(color: Color(backgroundHighlightColor), location: 0.618),
                            Gradient.Stop(color: .black, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                Text("Something went wrong, please try again.")
            }
        }
        .onChange(of: spotifyPlaybackManager.currentTrack, initial: true) {
            loadCoverImage()
        }
        .interactiveDismissDisabled(false)
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
