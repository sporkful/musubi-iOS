// AccountTabRoot.swift

import SwiftUI

struct AccountTabRoot: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Current session") {
                    Text("Logged in as: \(Musubi.UserManager.shared.currentUser?.spotifyInfo.display_name ?? "?")")
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
