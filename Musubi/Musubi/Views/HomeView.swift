// HomeView.swift

import SwiftUI

struct HomeView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    HomeView()
}
