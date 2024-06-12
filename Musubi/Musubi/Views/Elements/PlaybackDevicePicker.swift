// PlaybackDevicePicker.swift

import SwiftUI

// TODO: try custom menu, which might allow detecting when menu is expanded/retracted (finer-grained polling)

struct PlaybackDevicePicker: View {
    @Environment(SpotifyPlaybackManager.self) private var spotifyPlaybackManager
    
    let outerLabelStyle: CustomOuterLabelStyle
    
    enum CustomOuterLabelStyle {
        case iconOnly, textOnly
    }
    
    // only runs when picker is visible
    @State private var refreshPoller: Timer? = nil
    private let REFRESH_INTERVAL: TimeInterval = 5 // TODO: tune these for Spotify's rate limit
    private let REFRESH_TIMEOUT: TimeInterval = 3 * 60
    
    var body: some View {
        @Bindable var spotifyPlaybackManager = spotifyPlaybackManager
        
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
                    HStack {
                        Text(device.name)
                        Image(systemName: device.sfSymbolName)
                    }
                    .tag(Optional(index))
                }
                if spotifyPlaybackManager.activeDeviceIndex == nil {
                    Text("None").tag(nil as Int?)
                }
            },
            label: {
                if outerLabelStyle == .textOnly {
                    Text("Device")
                } else {
                    if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex {
                        Image(systemName: spotifyPlaybackManager.availableDevices[activeDeviceIndex].sfSymbolName)
                    } else {
                        Image(systemName: "iphone.sizes")
                    }
                }
            }
        )
        .onChange(of: spotifyPlaybackManager.activeDeviceIndex, initial: false) {
            Task { @MainActor in
                if let activeDeviceIndex = spotifyPlaybackManager.activeDeviceIndex,
                   let activeDeviceID = spotifyPlaybackManager.availableDevices[activeDeviceIndex].id
                {
                    try await spotifyPlaybackManager.transferPlaybackTo(deviceID: activeDeviceID)
                } else {
                    try await spotifyPlaybackManager.resetOnLossOfActiveDevice()
                }
            }
        }
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
