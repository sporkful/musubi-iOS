// HomeView.swift

import SwiftUI

// TODO: chaining actions on the same navpath doesn't work unless there's a large enough sleep between them
@MainActor
@Observable
class HomeViewCoordinator {
    var disableUI = false
    
    var openTab: Tab = .myRepos
    
    enum Tab {
        case myRepos
        case myForks
        case spotifySearch
        case myAccount
    }
    
    var myReposNavPath = NavigationPath()
    var myForksNavPath = NavigationPath()
    var spotifySearchNavPath = NavigationPath()
    var myAccountNavPath = NavigationPath()
    
    enum ScrollAnchor: Equatable, Hashable {
        case none
        case top
        case bottom
    }
    var myReposDesiredScrollAnchor: ScrollAnchor = .none
}

struct HomeView: View {
    var currentUser: Musubi.User
    
    @State var spotifyPlaybackManager: SpotifyPlaybackManager
    @State var homeViewCoordinator: HomeViewCoordinator
    
    var body: some View {
        TabView(selection: $homeViewCoordinator.openTab) {
            // MARK: - "My Repositories" tab
            NavigationStack(path: $homeViewCoordinator.myReposNavPath) {
                LocalClonesTabRoot()
                    .navigationDestination(for: Musubi.RepositoryReference.self) { repositoryReference in
                        // TODO: better error handling?
                        if let repositoryClone = currentUser.openLocalClone(repositoryHandle: repositoryReference.handle) {
                            LocalClonePage(
                                navigationPath: $homeViewCoordinator.myReposNavPath,
                                repositoryClone: repositoryClone
                            )
                        }
                    }
                    .withSpotifyNavigationDestinations(path: $homeViewCoordinator.myReposNavPath)
                    .navigationTitle("My Repositories")
            }
            .withMiniPlayerOverlay()
            .tabItem { Label("My Repositories", systemImage: "books.vertical") }
            .tag(HomeViewCoordinator.Tab.myRepos)
//                .badge("!") // TODO: notifications?
            
            // MARK: - "Spotify Search" tab
            NavigationStack(path: $homeViewCoordinator.spotifySearchNavPath) {
                SearchTabRoot()
                    .withSpotifyNavigationDestinations(path: $homeViewCoordinator.spotifySearchNavPath)
                    .navigationTitle("Search Spotify")
            }
            .withMiniPlayerOverlay()
            .tabItem { Label("Search Spotify", systemImage: "magnifyingglass") }
            .tag(HomeViewCoordinator.Tab.spotifySearch)
            
            // MARK: - "My Account" tab
            NavigationStack(path: $homeViewCoordinator.myAccountNavPath) {
                AccountTabRoot()
                    .navigationTitle("My Account")
            }
            .withMiniPlayerOverlay()
            .tabItem { Label("My Account", systemImage: "person.crop.circle.fill") }
            .tag(HomeViewCoordinator.Tab.myAccount)
        }
        .listStyle(.plain)
        .environment(currentUser)
        .environment(spotifyPlaybackManager)
        .environment(homeViewCoordinator)
        .withCustomDisablingOverlay(isDisabled: $homeViewCoordinator.disableUI)
        // TODO: overlay with floating playback card
    }
}

//#Preview {
//    HomeView()
//}
