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
