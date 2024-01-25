// AccountView.swift

import SwiftUI

struct AccountView: View {
    @Environment(Musubi.UserManager.self) private var userManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current session") {
                    Text("Logged in as: \(userManager.loggedInUser?.display_name ?? "")")
                    Button(role: .destructive) {
                        // TODO: "are you sure you want to log out? (dw your stuff is saved)"
                        userManager.logOut()
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
    AccountView()
}
