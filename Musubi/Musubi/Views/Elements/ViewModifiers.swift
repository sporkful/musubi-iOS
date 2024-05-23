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
}

private struct WithCustomDisablingOverlay: ViewModifier {
    @Binding var isDisabled: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!isDisabled)
            if isDisabled {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.360))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(.all, edges: .all)
                    ProgressView("Loading")
                        .controlSize(.large)
                        .padding()
                        .foregroundStyle(Color.white)
                        .bold()
                        .background(Color.gray.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
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
                    albumMetadata: albumMetadata
                )
            }
            .navigationDestination(for: Spotify.PlaylistMetadata.self) { playlistMetadata in
                StaticPlaylistPage(
                    navigationPath: $navigationPath,
                    playlistMetadata: playlistMetadata
                )
            }
            .navigationDestination(for: Spotify.OtherUser.self) { user in
                StaticUserPage(user: user)
            }
    }
}
