// LocalClonesTabRoot.swift

import SwiftUI

struct LocalClonesTabRoot: View {
    @Environment(Musubi.User.self) private var currentUser
    
    var body: some View {
        Text("\(currentUser.spotifyInfo.display_name)")
    }
}

#Preview {
    LocalClonesTabRoot()
}
