// SearchView.swift

import SwiftUI

struct SearchView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    @State private var navigationPath: [String] = []
    
    @State private var searchText = ""
    @State private var searchResults: Spotify.Model.SearchResults = Spotify.Model.SearchResults.blank()
    
    @State private var showAudioTrackResults = true
    @State private var showArtistResults = true
    @State private var showAlbumResults = true
    @State private var showPlaylistResults = true
    
    private static let thumbnailDimension: Double = Musubi.UIConstants.thumbnailDimension
    
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
                        }
                    }
                    if showArtistResults {
                        Section("Artists") {
                        }
                    }
                    if showAlbumResults {
                        Section("Albums") {
                        }
                    }
                    if showPlaylistResults {
                        Section("Playlists") {
                        }
                    }
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
                        print("(likely nonfatal) [spowerfy::SearchView] search spotify error")
                        print(error)
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
