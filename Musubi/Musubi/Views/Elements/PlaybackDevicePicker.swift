// PlaybackDevicePicker.swift

import SwiftUI

struct PlaybackDevicePicker: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    let outerLabelStyle: CustomOuterLabelStyle
    
    enum CustomOuterLabelStyle {
        case iconOnly, fullBody, fullFootnote
    }
    
    // only runs when picker is visible
    @State private var refreshPoller: Timer? = nil
    private let REFRESH_INTERVAL: TimeInterval = 5 // TODO: tune these for Spotify's rate limit
    private let REFRESH_TIMEOUT: TimeInterval = 3 * 60
    
    var body: some View {
        @Bindable var spotifyPlaybackManager = spotifyPlaybackManager
        
        Menu {
        Picker(
            selection: $spotifyPlaybackManager.activeDeviceIndex,
            content: {
                ForEach(
                    Array(zip(
                        spotifyPlaybackManager.availableDevices.indices,
                        spotifyPlaybackManager.availableDevices
                    )),
                    id: \.0
                ) { index, device in
                    Label(device.name, systemImage: device.sfSymbolName)
                        .tag(Optional(index))
                }
                if spotifyPlaybackManager.activeDeviceIndex == nil {
                    Text("None").tag(nil as Int?)
                }
            },
            label: {}
        )
        } label: {
                if outerLabelStyle == .iconOnly {
                    if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex {
                        Image(systemName: spotifyPlaybackManager.availableDevices[activeDeviceIndex].sfSymbolName)
                    } else {
                        Image(systemName: "iphone.sizes")
                    }
                } else if outerLabelStyle == .fullBody {
                    HStack {
                        if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex {
                            HStack {
                                Image(systemName: spotifyPlaybackManager.availableDevices[activeDeviceIndex].sfSymbolName)
                                Text(spotifyPlaybackManager.availableDevices[activeDeviceIndex].name)
                            }
                            .foregroundStyle(Color.green)
                        } else {
                            Text("None")
                        }
                        Image(systemName: "chevron.up.chevron.down")
                    }
                } else if outerLabelStyle == .fullFootnote {
                    if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex {
                        Label(
                            spotifyPlaybackManager.availableDevices[activeDeviceIndex].name,
                            systemImage: spotifyPlaybackManager.availableDevices[activeDeviceIndex].sfSymbolName
                        )
                        .font(.caption)
                        .foregroundStyle(Color.green)
                    } else {
                        Label(
                            "Select a device",
                            systemImage: "iphone.sizes"
                        )
                        .font(.caption)
                        .opacity(0.81)
                    }
                } else {
                    Text("Device")
                }
        }
        .onChange(of: spotifyPlaybackManager.activeDeviceIndex, initial: false) {
            Task { @MainActor in
                if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex,
                   let activeDeviceID = spotifyPlaybackManager.availableDevices[activeDeviceIndex].id
                {
                    try await spotifyPlaybackManager.transferPlaybackTo(deviceID: activeDeviceID)
                } else {
                    await spotifyPlaybackManager.resetOnLossOfActiveDevice()
                }
            }
        }
        // TODO: figure out how to attach callbacks to menu expanding/collapsing (attaching to inner picker doesn't work)
        .onAppear(perform: startPoller)
        .onDisappear(perform: stopPoller)
    }
    
    private func startPoller() {
        if self.refreshPoller == nil {
            self.refreshPoller = Timer.scheduledTimer(withTimeInterval: REFRESH_INTERVAL, repeats: true) { _ in
                Task {
                    try await spotifyPlaybackManager.updateAvailableDevices()
                }
            }
            self.refreshPoller?.fire()
            Timer.scheduledTimer(withTimeInterval: REFRESH_TIMEOUT, repeats: false) { _ in
                stopPoller()
            }
        }
    }
    
    private func stopPoller() {
        self.refreshPoller?.invalidate()
        self.refreshPoller = nil
    }
}

//#Preview {
//    PlaybackDevicePicker()
//}
