// AccountTabRoot.swift

import SwiftUI

struct AccountTabRoot: View {
    var body: some View {
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
                Section {
                    HStack {
                        Text("Device")
                        Spacer()
                        PlaybackDevicePicker(outerLabelStyle: .fullBody)
                    }
                } header: {
                    Text("Playback")
                } footer: {
                    Text(
                        """
                        In order for a device to show up as an option here, the device \
                        must have the official Spotify app or web-player open in the background.
                        """
                    )
                }
            }
    }
}

#Preview {
    AccountTabRoot()
}
