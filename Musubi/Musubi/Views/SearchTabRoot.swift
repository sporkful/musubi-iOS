// SearchTabRoot.swift

import SwiftUI
import AsyncAlgorithms

struct SearchTabRoot: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @State private var navigationPath = NavigationPath()
    
    @State private var searchText = ""
    @State private var searchResults: Spotify.SearchResults = Spotify.SearchResults.blank()
    
    let searchQueue = AsyncChannel<String>()
    @State private var searchQueueSize = 0
    
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
                .navigationDestination(for: Spotify.Artist.self) { artist in
                    StaticArtistPage(artist: artist)
                }
                .navigationDestination(for: Spotify.Album.self) { album in
                    StaticAlbumPage(
                        navigationPath: $navigationPath,
                        album: album,
                        name: album.name,
                        coverImageURLString: album.images?.first?.url
                    )
                }
                .navigationDestination(for: Spotify.Playlist.self) { playlist in
                    StaticPlaylistPage(
                        navigationPath: $navigationPath,
                        playlist: playlist,
                        name: playlist.name,
                        description: playlist.descriptionTextFromHTML,
                        coverImageURLString: playlist.images?.first?.url
                    )
                }
                .navigationDestination(for: Spotify.OtherUser.self) { user in
                    StaticUserPage(user: user)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer)
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    self.searchQueueSize += 1
                    await self.searchQueue.send(newValue)
                }
            }
            .task {
                await processSearchQueue()
            }
            .navigationTitle("Search Spotify")
        }
    }
    
    private func processSearchQueue() async {
        var iter = searchQueue.makeAsyncIterator()
        while true {
            // Avoid dispatching / waiting for Spotify requests for intermediate queries generated
            // by the user's typing process.
            var query: String
            repeat {
                query = await iter.next()!
                self.searchQueueSize -= 1
            } while self.searchQueueSize > 0
            
            if !query.isEmpty {
                do {
                    self.searchResults = try await SpotifyRequests.Read.search(
                        query: query,
                        userManager: userManager
                    )
                } catch {
                    print("[Musubi::SearchView] search spotify error")
                    print(error.localizedDescription)
                    self.searchResults = Spotify.SearchResults.blank()
                }
            } else {
                self.searchResults = Spotify.SearchResults.blank()
            }
        }
    }
}

#Preview {
    SearchTabRoot()
}
