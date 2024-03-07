// HomeView.swift

import SwiftUI

struct HomeView: View {
    @Environment(Musubi.User.self) private var currentUser
    
    var body: some View {
        TabView {
            LocalReposView()
                .tabItem {
                    Label("My Local Repositories", systemImage: "books.vertical")
                }
            SearchView()
                .tabItem {
                    Label("Search Spotify", systemImage: "magnifyingglass")
                }
            AccountView()
//                .badge("!") // TODO: notifications
                .tabItem {
                    Label("My Account", systemImage: "person.crop.circle.fill")
                }
        }
        // TODO: overlay with floating playback card
    }
}

#Preview {
    HomeView()
}
