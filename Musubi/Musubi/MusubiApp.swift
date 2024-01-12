// MusubiApp.swift

import SwiftUI

@main
struct MusubiApp: App {
    @State private var spotifyWebClient = SpotifyWebClient()
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
                .environment(spotifyWebClient)
        }
    }
}

// namespaces
struct Musubi {
    private init() { }
    
    struct Model {
        private init() { }
    }
    
    struct ViewModel {
        private init() { }
    }
}
