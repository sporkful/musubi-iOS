// HomeView.swift

import SwiftUI

struct HomeView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    var body: some View {
        TabView {
            LocalReposView()
                .tabItem {
                    Label("My Local Repositories", systemImage: "books.vertical")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            AccountView()
//                .badge("!") // TODO: notifications
                .tabItem {
                    Label("My Account", systemImage: "person.crop.circle.fill")
                }
        }
        .onAppear {
            // TODO: if this is a new Musubi user, trigger alert then set up e.g. provision storage
            // TODO: start playback controller if this is a premium user
        }
        // TODO: overlay with floating playback card
    }
}

#Preview {
    HomeView()
}
