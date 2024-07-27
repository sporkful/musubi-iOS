// MusubiApp.swift

import SwiftUI

// TODO: tint vs foregroundColor?

@main
struct MusubiApp: App {
  var body: some Scene {
    WindowGroup {
      LoginView()
        .preferredColorScheme(.dark)
        .tint(.white)
    }
  }
}

// namespaces
struct Musubi {
  private init() { }
}
