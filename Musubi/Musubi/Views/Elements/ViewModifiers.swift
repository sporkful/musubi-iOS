// ViewModifiers.swift

import Foundation
import SwiftUI

extension View {
    func withCustomDisablingOverlay(isDisabled: Binding<Bool>) -> some View {
        modifier(WithCustomDisablingOverlay(isDisabled: isDisabled))
    }
    
    func withSpotifyNavigationDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(WithSpotifyNavigationDestinations(navigationPath: path))
    }
    
    func withCustomSheetNavbar(
        caption: String?,
        title: String,
        cancellationControl: CustomSheetNavbar.Control?,
        primaryControl: CustomSheetNavbar.Control?
    ) -> some View {
        modifier(
            CustomSheetNavbar(
                caption: caption,
                title: title,
                cancellationControl: cancellationControl,
                primaryControl: primaryControl
            )
        )
    }
    
    func withMiniPlayerOverlay() -> some View {
        modifier(MiniPlayerOverlay())
    }
}

private struct WithCustomDisablingOverlay: ViewModifier {
    @Binding var isDisabled: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
//                .allowsHitTesting(!isDisabled)
                .disabled(isDisabled)
            if isDisabled {
//                ZStack {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.360))
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .ignoresSafeArea(.all, edges: .all)
                    ProgressView("Loading")
                        .controlSize(.large)
                        .padding()
                        .foregroundStyle(Color.white)
                        .bold()
                        .background(Color.gray.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
//                }
            }
        }
    }
}

private struct WithSpotifyNavigationDestinations: ViewModifier {
    @Binding var navigationPath: NavigationPath
    
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Spotify.ArtistMetadata.self) { artistMetadata in
                StaticArtistPage(artistMetadata: artistMetadata)
            }
            .navigationDestination(for: Spotify.AlbumMetadata.self) { albumMetadata in
                StaticAlbumPage(
                    navigationPath: $navigationPath,
                    audioTrackList: .init(albumMetadata: albumMetadata)
                )
            }
            .navigationDestination(for: Spotify.PlaylistMetadata.self) { playlistMetadata in
                StaticPlaylistPage(
                    navigationPath: $navigationPath,
                    audioTrackList: .init(playlistMetadata: playlistMetadata)
                )
            }
            .navigationDestination(for: Spotify.OtherUser.self) { user in
                StaticUserPage(user: user)
            }
    }
}

struct CustomSheetNavbar: ViewModifier {
    let caption: String?
    let title: String
    
    let cancellationControl: Control?
    let primaryControl: Control?
    
    struct Control {
        let title: String
        let action: () -> Void
    }
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        if let caption = caption {
                            Text(caption)
                                .font(.caption)
                        }
                        Text(title)
                            .font(.headline)
                    }
                    .padding(.vertical, 5)
                }
                if let cancellationControl = self.cancellationControl {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(
                            action: cancellationControl.action,
                            label: {
                                Text(cancellationControl.title)
                            }
                        )
                    }
                }
                if let primaryControl = self.primaryControl {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(
                            action: primaryControl.action,
                            label: {
                                Text(primaryControl.title)
                                    .bold()
                            }
                        )
                    }
                } else {
                    // invisible balancer
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(cancellationControl?.title ?? "Cancel")
                            .hidden()
                    }
                }
            }
    }
}

private struct MiniPlayerOverlay: ViewModifier {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    @State private var thumbnail: UIImage? = nil
    
    private var backgroundHighlightColor: UIColor { thumbnail?.meanColor()?.muted() ?? .gray }
    
    let THUMBNAIL_SIZE = Musubi.UI.ImageDimension.cellThumbnail.rawValue
    
    @State private var showSheetPlayer = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if let currentTrack = spotifyPlaybackManager.currentTrack {
                VStack(alignment: .center, spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            HStack {
                            if let thumbnail = thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE)
                                    .clipped()
                            } else {
                                ProgressView()
                                    .frame(width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE)
                            }
                            VStack(alignment: .leading) {
                                Text(currentTrack.audioTrack.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .padding(.bottom, 0.0127)
                                Text(currentTrack.audioTrack.caption ?? "")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .opacity(0.9)
                            }
                            Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(perform: { showSheetPlayer = true })
                            if spotifyPlaybackManager.isPlaying {
                                Button(
                                    action: {
                                        Task { try await spotifyPlaybackManager.pause() }
                                    },
                                    label: {
                                        Image(systemName: "pause.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: THUMBNAIL_SIZE * 0.420, height: THUMBNAIL_SIZE * 0.420)
                                            .clipped()
                                            .padding(.trailing, 6.30)
                                    }
                                )
                            } else {
                                Button(
                                    action: {
                                        Task { try await spotifyPlaybackManager.resume() }
                                    },
                                    label: {
                                        Image(systemName: "play.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: THUMBNAIL_SIZE * 0.420, height: THUMBNAIL_SIZE * 0.420)
                                            .clipped()
                                            .padding(.trailing, 6.30)
                                    }
                                )
                            }
                        }
                        .frame(maxHeight: THUMBNAIL_SIZE)
                        .padding(6.30)
                        ProgressView(
                            value: Double(spotifyPlaybackManager.positionMilliseconds),
                            total: Double(currentTrack.audioTrack.duration_ms)
                        )
                        .tint(.white)
                        .background(.white.opacity(0.630))
                        .scaleEffect(x: 1, y: 0.630, anchor: .center)
                    }
                    .background(Color(backgroundHighlightColor))
                    .clipShape(.rect(cornerRadius: 9.87))
                    .padding([.horizontal], 3)
                    .shadow(color: .black, radius: 33)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .sheet(isPresented: $showSheetPlayer) {
            PlayerSheet(showSheet: $showSheetPlayer)
        }
        .onChange(of: spotifyPlaybackManager.currentTrack, initial: true) {
            loadThumbnail()
        }
        .onChange(of: spotifyPlaybackManager.activeDeviceIndex, initial: false) {
            Task { @MainActor in
                if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex,
                   let activeDeviceID = spotifyPlaybackManager.availableDevices[activeDeviceIndex].id
                {
                    return
                } else {
                    try await spotifyPlaybackManager.resetOnLossOfActiveDevice()
                }
            }
        }
    }
    
    // TODO: share logic with RetryableAsyncImage?
    private func loadThumbnail() {
        Task { @MainActor in
            while true {
                if let thumbnailURLString = spotifyPlaybackManager.currentTrack?.audioTrack.thumbnailURLString,
                   let thumbnailURL = URL(string: thumbnailURLString),
                   let thumbnail = try? await SpotifyRequests.Read.image(url: thumbnailURL)
                {
                    self.thumbnail = thumbnail
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
}
