// HomeView.swift

import SwiftUI

struct HomeView: View {
    var currentUser: Musubi.User
    
    var body: some View {
        TabView {
            LocalClonesTabRoot()
                .environment(currentUser)
                .tabItem { Label("My Local Repositories", systemImage: "books.vertical") }
            SearchTabRoot()
                .tabItem { Label("Search Spotify", systemImage: "magnifyingglass") }
            AccountTabRoot()
//                .badge("!") // TODO: notifications
                .tabItem { Label("My Account", systemImage: "person.crop.circle.fill") }
        }
        // TODO: overlay with floating playback card
    }
}

//#Preview {
//    HomeView()
//}
