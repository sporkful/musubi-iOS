// StaticUserPage.swift

import SwiftUI

struct StaticUserPage: View {
    let user: Spotify.OtherUser
    
    var body: some View {
        Text("User \(user.name)")
    }
}

//#Preview {
//    StaticUserPage()
//}
