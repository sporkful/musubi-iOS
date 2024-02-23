// MusubiApp.swift

import SwiftUI

@main
struct MusubiApp: App {
    @State private var userManager = Musubi.UserManager()
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
                .tint(.white)
                .environment(userManager)
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
