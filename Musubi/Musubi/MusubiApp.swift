// MusubiApp.swift

import SwiftUI

@main
struct MusubiApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
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
