// AccountTabRoot.swift

import SwiftUI

struct AccountTabRoot: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Current session") {
                    if let currentUser = Musubi.UserManager.shared.currentUser {
                        Text("Logged in as: \(currentUser.spotifyInfo.name)")
                    } else {
                        Text("No user detected. Please log out below and log back in!")
                    }
                    Button(role: .destructive) {
                        // TODO: "are you sure you want to log out? (dw your stuff is saved)"
                        Musubi.UserManager.shared.logOut()
                    } label: {
                        Text("Log out")
                    }
                }
            }
            .navigationTitle("My Account")
        }
    }
}

#Preview {
    AccountTabRoot()
}
