// HomeView.swift

import SwiftUI

// TODO: chaining actions on the same navpath doesn't work unless there's a large enough sleep between them
// TODO: can't do smart nav (e.g. skipping append if already navPath.last) with provided NavigationPath type
@MainActor
@Observable
class HomeViewCoordinator {
    var disableUI = false
    
    var openTab: Tab = .myRepos
    
    enum Tab {
        case myRepos
        case spotifySearch
        case myAccount
    }
    
    var myReposNavPath = NavigationPath()
    var spotifySearchNavPath = NavigationPath()
    var myAccountNavPath = NavigationPath()
    
    enum ScrollAnchor: Equatable, Hashable {
        case none
        case top
        case bottom
    }
    var myReposDesiredScrollAnchor: ScrollAnchor = .none
    
    var showSheetCommitHistory = false
    
    // TODO: pass in a binding to source `showSheet` and dismiss it from here
    func openSpotifyNavigable(_ spotifyNavigable: any SpotifyNavigable) async throws {
        self.disableUI = true
        defer { self.disableUI = false }
        
        try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
        if self.openTab != .spotifySearch {
            self.openTab = .spotifySearch
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
        }
        self.spotifySearchNavPath.append(spotifyNavigable)
    }
    
    func openMusubiNavigable(_ musubiNavigable: any MusubiNavigable) async throws {
        self.disableUI = true
        defer { self.disableUI = false }
        
        if let repositoryReference = musubiNavigable as? Musubi.RepositoryReference {
            try await self.open(repositoryReference: repositoryReference)
        } else if let repositoryCommit = musubiNavigable as? Musubi.RepositoryCommit {
            // Note openedLocalClone doesn't get reset when navigated away from - it only gets changed
            // when user explicitly opens a new local clone.
//            if Musubi.UserManager.shared.currentUser?.openedLocalClone?.repositoryReference != repositoryCommit.repositoryReference {
                try await self.open(repositoryReference: repositoryCommit.repositoryReference)
//            }
            
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
            showSheetCommitHistory = true
        }
    }
    
    // MARK: The following helpers assume disableUI has already been set.
    
    // TODO: explicitly handle case where repositoryReference was deleted by user but kept by context
    private func open(repositoryReference: Musubi.RepositoryReference) async throws {
        self.myReposNavPath.removeLast(self.myReposNavPath.count)
        try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
        if self.openTab != .myRepos {
            self.openTab = .myRepos
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
        }
        
        // TODO: scroll to correct position?
//        homeViewCoordinator.myReposDesiredScrollAnchor =
//        try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
//        homeViewCoordinator.myReposDesiredScrollAnchor = .none
        
        self.myReposNavPath.append(repositoryReference)
    }
}

struct HomeView: View {
    @Environment(\.scenePhase) var scenePhase
    
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
                        if let repositoryClone = currentUser.openLocalClone(repositoryReference: repositoryReference) {
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
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                Task {
                    await spotifyPlaybackManager.remotePlaybackPollerAction(overrideIgnore: true)
                }
            }
        }
    }
}

//#Preview {
//    HomeView()
//}
