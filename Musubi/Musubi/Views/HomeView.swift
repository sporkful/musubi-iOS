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
                    .navigationDestination(for: Musubi.RepositoryHandle.self) { repositoryHandle in
                        // TODO: better error handling?
                        if let repositoryClone = currentUser.openLocalClone(repositoryHandle: repositoryHandle) {
                            LocalClonePage(
                                navigationPath: $homeViewCoordinator.myReposNavPath,
                                repositoryClone: repositoryClone
                            )
                        }
                    }
                    .withSpotifyNavigationDestinations(path: $homeViewCoordinator.myReposNavPath)
                    .navigationTitle("My Repositories")
            }
            .tabItem { Label("My Repositories", systemImage: "books.vertical") }
            .tag(HomeViewCoordinator.Tab.myRepos)
//                .badge("!") // TODO: notifications?
            
            // MARK: - "My Forks" tab
            NavigationStack(path: $homeViewCoordinator.myForksNavPath) {
                // TODO: new view and navigationDestination modifier for forks
                VStack { }
            }
            .tabItem { Label("My forks", systemImage: "arrow.triangle.branch") }
            .tag(HomeViewCoordinator.Tab.myForks)
            
            // MARK: - "Spotify Search" tab
            NavigationStack(path: $homeViewCoordinator.spotifySearchNavPath) {
                SearchTabRoot()
                    .withSpotifyNavigationDestinations(path: $homeViewCoordinator.spotifySearchNavPath)
                    .navigationTitle("Search Spotify")
            }
            .tabItem { Label("Search Spotify", systemImage: "magnifyingglass") }
            .tag(HomeViewCoordinator.Tab.spotifySearch)
            
            // MARK: - "My Account" tab
            NavigationStack(path: $homeViewCoordinator.myAccountNavPath) {
                AccountTabRoot()
                    .navigationTitle("My Account")
            }
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
