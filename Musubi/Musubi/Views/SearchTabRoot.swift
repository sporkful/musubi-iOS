// SearchTabRoot.swift

import SwiftUI
import AsyncAlgorithms

struct SearchTabRoot: View {
    @Environment(HomeViewCoordinator.self) private var homeViewCoordinator
    
    @State private var searchText = ""
    @State private var searchResults: Spotify.SearchResults = Spotify.SearchResults.blank
    
    @State private var searchQueue = AsyncChannel<String>()
    @State private var searchQueueSize = 0
    
    @State private var showAudioTrackResults = true
    @State private var showArtistResults = true
    @State private var showAlbumResults = true
    @State private var showPlaylistResults = true
    
    var body: some View {
            @Bindable var homeViewCoordinator = homeViewCoordinator
        
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
                                    isNavigable: true,
                                    navigationPath: $homeViewCoordinator.spotifySearchNavPath,
                                    audioTrackListElement: Musubi.ViewModel.AudioTrackList.UniquifiedElement(
                                        audioTrack: audioTrack
                                    ),
                                    showThumbnail: true,
                                    customTextStyle: .defaultStyle
                                )
                            }
                        }
                    }
                    if showArtistResults {
                        Section("Artists") {
                            ForEach(searchResults.artists.items) { artistMetadata in
                                NavigationLink(value: artistMetadata) {
                                    ListCellWrapper(
                                        item: artistMetadata,
                                        showThumbnail: true,
                                        customTextStyle: .defaultStyle
                                    )
                                }
                            }
                        }
                    }
                    if showAlbumResults {
                        Section("Albums") {
                            ForEach(searchResults.albums.items) { albumMetadata in
                                NavigationLink(value: albumMetadata) {
                                    ListCellWrapper(
                                        item: albumMetadata,
                                        showThumbnail: true,
                                        customTextStyle: .defaultStyle
                                    )
                                }
                            }
                        }
                    }
                    if showPlaylistResults {
                        Section("Playlists") {
                            ForEach(searchResults.playlists.items) { playlistMetadata in
                                NavigationLink(value: playlistMetadata) {
                                    ListCellWrapper(
                                        item: playlistMetadata,
                                        showThumbnail: true,
                                        customTextStyle: .defaultStyle
                                    )
                                }
                            }
                        }
                    }
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
    }
    
    private func processSearchQueue() async {
        searchQueue = AsyncChannel<String>()
        searchQueueSize = 0
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
