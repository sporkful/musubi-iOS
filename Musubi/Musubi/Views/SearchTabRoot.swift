// SearchTabRoot.swift

import SwiftUI
import AsyncAlgorithms

struct SearchTabRoot: View {
  @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
  
  @State private var myPlaylists: [Spotify.PlaylistMetadata] = []  // i.e. owned by current user
  
  @State private var searchText = ""
  @State private var searchResults: Spotify.SearchResults = Spotify.SearchResults.blank
  
  @State private var searchQueue = AsyncChannel<String>()
  @State private var searchQueueSize = 0
  
  struct SearchResultsView: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    @Environment(\.isSearching) private var isSearching
    
    @Binding var myPlaylists: [Spotify.PlaylistMetadata]
    
    @Binding var searchText: String
    @Binding var searchResults: Spotify.SearchResults
    
    private var myFilteredPlaylists: [Spotify.PlaylistMetadata] {
      if isSearching && !searchText.isEmpty {
        return myPlaylists.filter({ $0.name.lowercased().contains(searchText.lowercased()) })
      } else {
        return myPlaylists
      }
    }
    
    @State private var showMyPlaylistResults = true
    @State private var showAllPlaylistResults = false
    @State private var showAudioTrackResults = false
    @State private var showArtistResults = false
    @State private var showAlbumResults = false
    
    struct CustomToggle: View {
      let title: String
      @Binding var isOn: Bool
      
      var body: some View {
        Button(
          action: { isOn.toggle() },
          label: { Text(title).font(.caption).bold().padding(10) }
        )
        .foregroundStyle(isOn ? .black : .white)
        .background(isOn ? .green : .gray.opacity(0.5))
        .clipShape(Capsule())
      }
    }
    
    let FILTER_BAR_EDGE_SHADOW: CGFloat = 10
    
    var body: some View {
      VStack {
        if isSearching {
          ScrollView(.horizontal) {
            HStack {
              Rectangle()
                .frame(width: FILTER_BAR_EDGE_SHADOW)
                .frame(maxHeight: .infinity)
                .hidden()
              CustomToggle(title: "My Playlists", isOn: $showMyPlaylistResults)
              CustomToggle(title: "All Playlists", isOn: $showAllPlaylistResults)
              CustomToggle(title: "Tracks", isOn: $showAudioTrackResults)
              CustomToggle(title: "Artists", isOn: $showArtistResults)
              CustomToggle(title: "Albums", isOn: $showAlbumResults)
              Rectangle()
                .frame(width: FILTER_BAR_EDGE_SHADOW)
                .frame(maxHeight: .infinity)
                .hidden()
            }
            .fixedSize(horizontal: false, vertical: true)
          }
          .scrollIndicators(.hidden)
          .overlay {
            HStack {
              LinearGradient(
                gradient: Gradient(colors: [.black, .clear]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: FILTER_BAR_EDGE_SHADOW)
              .frame(maxHeight: .infinity)
              Spacer()
              LinearGradient(
                gradient: Gradient(colors: [.clear, .black]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .frame(width: FILTER_BAR_EDGE_SHADOW)
              .frame(maxHeight: .infinity)
            }
          }
        }
        List {
          if !isSearching || showMyPlaylistResults {
            Section("My Playlists") {
              ForEach(myFilteredPlaylists) { playlistMetadata in
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
          if isSearching {
            if showAllPlaylistResults {
              Section("All Playlists") {
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
            if showAudioTrackResults {
              Section("Tracks") {
                ForEach(searchResults.tracks.items) { audioTrack in
                  ListCellWrapper(
                    item: Musubi.ViewModel.AudioTrack(audioTrack: audioTrack),
                    showThumbnail: true,
                    customTextStyle: .defaultStyle,
                    showAudioTrackMenu: true
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
          }
          if spotifyPlaybackManager.currentTrack != nil {
            Rectangle()
              .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
              .padding(6.30 + 3.30)
              .hidden()
          }
        }
      }
    }
  }
  
  var body: some View {
    SearchResultsView(myPlaylists: $myPlaylists, searchText: $searchText, searchResults: $searchResults)
      .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
      .onChange(of: searchText, initial: true) { oldValue, newValue in
        Task {
          self.searchQueueSize += 1
          await self.searchQueue.send(newValue)
        }
        
        loadMyPlaylists()
      }
      .task {
        await processSearchQueue()
      }
      .alert(
        "Error when loading current user's playlists",
        isPresented: $showAlertErrorLoadingMyPlaylists,
        actions: {},
        message: {
          Text("Will automatically retry the next time you switch from another tab to this one.")
        }
      )
  }
  
  @State private var isLoadingMyPlaylists = false
  @State private var showAlertErrorLoadingMyPlaylists = false
  @State private var lastAttemptedRefresh: Date = Date.distantPast
  private let REFRESH_COOLDOWN: TimeInterval = 60.0 // TODO: tune this for Spotify's rate limit
  
  private func loadMyPlaylists() {
    Task { @MainActor in
      guard !isLoadingMyPlaylists && Date.now.timeIntervalSince(lastAttemptedRefresh) > REFRESH_COOLDOWN else {
        return
      }
      
      isLoadingMyPlaylists = true
      defer { isLoadingMyPlaylists = false }
      lastAttemptedRefresh = Date.now
      
      do {
        self.myPlaylists = []
        for try await sublist in SpotifyRequests.Read.currentUserOwnedPlaylists() {
          self.myPlaylists.append(contentsOf: sublist)
        }
      } catch {
        print("[Musubi::SearchTabRoot] error when loading all my owned playlists")
        print(error.localizedDescription)
        showAlertErrorLoadingMyPlaylists = true
      }
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
