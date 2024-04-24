// SearchTabRoot.swift

import SwiftUI
import AsyncAlgorithms

struct SearchTabRoot: View {
    @State private var navigationPath = NavigationPath()
    
    @State private var searchText = ""
    @State private var searchResults: Spotify.SearchResults = Spotify.SearchResults.blank
    
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
                                AudioTrackListCell(
                                    navigationPath: $navigationPath,
                                    audioTrack: audioTrack,
                                    showThumbnail: true
                                )
                            }
                        }
                    }
                    if showArtistResults {
                        Section("Artists") {
                            ForEach(searchResults.artists.items) { artistMetadata in
                                NavigationLink(value: artistMetadata) {
                                    ListCell(item: artistMetadata)
                                }
                            }
                        }
                    }
                    if showAlbumResults {
                        Section("Albums") {
                            ForEach(searchResults.albums.items) { albumMetadata in
                                NavigationLink(value: albumMetadata) {
                                    ListCell(item: albumMetadata)
                                }
                            }
                        }
                    }
                    if showPlaylistResults {
                        Section("Playlists") {
                            ForEach(searchResults.playlists.items) { playlistMetadata in
                                NavigationLink(value: playlistMetadata) {
                                    ListCell(item: playlistMetadata)
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: Spotify.ArtistMetadata.self) { artistMetadata in
                    StaticArtistPage(artistMetadata: artistMetadata)
                }
                .navigationDestination(for: Spotify.AlbumMetadata.self) { albumMetadata in
                    StaticAlbumPage(
                        navigationPath: $navigationPath,
                        albumMetadata: albumMetadata,
                        name: albumMetadata.name,
                        coverImageURLString: albumMetadata.images?.first?.url
                    )
                }
                .navigationDestination(for: Spotify.PlaylistMetadata.self) { playlistMetadata in
                    StaticPlaylistPage(
                        navigationPath: $navigationPath,
                        playlistMetadata: playlistMetadata,
                        name: playlistMetadata.name,
                        description: playlistMetadata.descriptionTextFromHTML,
                        coverImageURLString: playlistMetadata.images?.first?.url
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
                guard let next = await iter.next() else {
                    return
                }
                query = next
                self.searchQueueSize -= 1
            } while self.searchQueueSize > 0
            
            if !query.isEmpty {
                do {
                    self.searchResults = try await SpotifyRequests.Read.search(query: query)
                } catch {
                    print("[Musubi::SearchView] search spotify error")
                    print(error.localizedDescription)
                    self.searchResults = Spotify.SearchResults.blank
                }
            } else {
                self.searchResults = Spotify.SearchResults.blank
            }
        }
    }
}

#Preview {
    SearchTabRoot()
}
