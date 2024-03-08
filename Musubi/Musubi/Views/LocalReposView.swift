// LocalReposView.swift

import SwiftUI

struct LocalReposView: View {
    @Environment(Musubi.User.self) private var currentUser
    
    var body: some View {
        Text("\(currentUser.spotifyInfo.display_name)")
    }
}

#Preview {
    LocalReposView()
}
