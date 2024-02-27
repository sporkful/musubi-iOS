// SearchView.swift

import SwiftUI

struct SearchView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @State private var navigationPath = NavigationPath()
    
    @State private var searchText = ""
    @State private var searchResults: Spotify.Model.SearchResults = Spotify.Model.SearchResults.blank()
    
    @State private var showAudioTrackResults = true
    @State private var showArtistResults = true
    @State private var showAlbumResults = true
    @State private var showPlaylistResults = true
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                HStack {
                    Spacer()
                    Toggle("Tracks", isOn: $showAudioTrackResults)
                        .toggleStyle(.button)
                    Spacer()
                    Toggle("Artists", isOn: $showArtistResults)
                        .toggleStyle(.button)
                    Spacer()
                    Toggle("Albums", isOn: $showAlbumResults)
                        .toggleStyle(.button)
                    Spacer()
                    Toggle("Playlists", isOn: $showPlaylistResults)
                        .toggleStyle(.button)
                    Spacer()
                    // TODO: filter for user's own playlists
                }
                List {
                    if showAudioTrackResults {
                        Section("Tracks") {
                            ForEach(searchResults.tracks.items) { audioTrack in
                                AudioTrackListCell(audioTrack: audioTrack, navigationPath: $navigationPath)
                            }
                        }
                    }
                    if showArtistResults {
                        Section("Artists") {
                            ForEach(searchResults.artists.items) { artist in
                                NavigationLink(value: artist) {
                                    ListCell(item: artist)
                                }
                            }
                        }
                    }
                    if showAlbumResults {
                        Section("Albums") {
                            ForEach(searchResults.albums.items) { album in
                                NavigationLink(value: album) {
                                    ListCell(item: album)
                                }
                            }
                        }
                    }
                    if showPlaylistResults {
                        Section("Playlists") {
                            ForEach(searchResults.playlists.items) { playlist in
                                NavigationLink(value: playlist) {
                                    ListCell(item: playlist)
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: Spotify.Model.Artist.self) { artist in
//                    ArtistStaticPageView(artist: artist)
                }
                .navigationDestination(for: Spotify.Model.Album.self) { album in
                    StaticAlbumPage(navigationPath: $navigationPath, album: album, name: album.name)
                }
                .navigationDestination(for: Spotify.Model.Playlist.self) { playlist in
//                    PlaylistStaticPageView(playlist: playlist)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer)
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    do {
                        searchResults = try await Spotify.Requests.Read.search(
                            query: newValue,
                            userManager: userManager
                        )
                    } catch {
                        print("[Musubi::SearchView] (likely nonfatal) search spotify error")
                        print(error)
                        searchResults = Spotify.Model.SearchResults.blank()
                    }
                }
            }
            .navigationTitle("Search Spotify")
        }
    }
}

#Preview {
    SearchView()
}
