// SpotifyPlaybackManager.swift

import Foundation

// TODO: resolve redundant/conflicting notions of context between AudioTrackList and PlaybackManager

@Observable
@MainActor
class SpotifyPlaybackManager {
    private(set) var availableDevices: [AvailableDeviceInfo: String] // value = deviceID (volatile)
    private(set) var activeDevice: AvailableDeviceInfo?
    private(set) var isPlaying: Bool
    private(set) var currentTrack: Musubi.ViewModel.AudioTrackList.UniquifiedElement?
    private(set) var context: Context
    private(set) var repeatState: LocalRepeatState
    private(set) var positionMilliseconds: Double // needs to be double type for SwiftUI Slider
    
    // Used to prevent conflicting concurrent remote-seek-requests when user is scrubbing.
    var isRequestingRemoteSeek: Bool
    
    let POSITION_MS_SLIDER_MIN = 10.0
    
    enum Context: Equatable {
        case local(context: (any AudioTrackListContext)?)
        case remote(uri: String?)
        
        static func == (lhs: SpotifyPlaybackManager.Context, rhs: SpotifyPlaybackManager.Context) -> Bool {
            // Avoid using `default` so cases added in the future will be forced to be implemented.
            switch (lhs, rhs) {
            case (let .local(lhsContext), let .local(rhsContext)):
                lhsContext?.id == rhsContext?.id
            case (let .remote(lhsURI), let .remote(rhsURI)):
                lhsURI == rhsURI
            case (.local, .remote):
                false
            case (.remote, .local):
                false
            }
        }
    }
    
    enum LocalRepeatState: Equatable {
        case off, track, context
        
        fileprivate init(remoteRepeatState: Remote.PlaybackState.RepeatState) {
            self = switch remoteRepeatState {
                case .off: .off
                case .track: .track
                case .context: .context
            }
        }
    }
    
    struct AvailableDeviceInfo: Equatable, Hashable {
        let is_restricted: Bool
        let name: String
        let type: String // e.g. "computer", "smartphone", "speaker", etc.
        
        // TODO: enumify type? need to handle unknown cases though
        
        fileprivate init(availableDevice: Remote.AvailableDevice) {
            self.is_restricted = availableDevice.is_restricted
            self.name = availableDevice.name
            self.type = availableDevice.type
        }
    }
    
    init() {
        self.availableDevices = [:]
        self.activeDevice = nil
        self.isPlaying = false
        self.currentTrack = nil
        self.context = .remote(uri: nil)
        self.repeatState = .context
        self.positionMilliseconds = 0
        self.isRequestingRemoteSeek = false
        
        Task {
            await startRemoteDevicesPoller()
            await startRemotePlaybackPoller()
            await startLocalPlaybackPoller()
        }
    }
    
    private var remoteDevicesPoller: Timer? = nil // polls Spotify for available devices
    private var remotePlaybackPoller: Timer? = nil // polls Spotify for actual current playback state
    private var localPlaybackPoller: Timer? = nil // interpolates self.position between remotePlaybackPoller firings
    
    // in seconds
    private let REMOTE_DEVICES_POLLER_INTERVAL: TimeInterval = 5 * 60.0
    private let REMOTE_PLAYBACK_POLLER_INTERVAL: TimeInterval = 5.0 // kept high to stay within Spotify rate limits
    private let LOCAL_PLAYBACK_POLLER_INTERVAL: TimeInterval = 1.0
    
    // TODO: proper ARC management
    // (current iteration should be fine for MVP since this object is global wrt user)
    
    private func startPoller(timeInterval: TimeInterval, action: @escaping () async -> Void) -> Timer {
        let timer = Timer(
            timeInterval: timeInterval,
            repeats: true,
            block: { _ in Task { await action() } }
        )
        RunLoop.current.add(timer, forMode: .common)
        timer.fire()
        return timer
    }
    
    func startRemoteDevicesPoller() async {
        if self.remoteDevicesPoller == nil {
            self.remoteDevicesPoller = startPoller(
                timeInterval: REMOTE_DEVICES_POLLER_INTERVAL,
                action: remoteDevicesPollerAction
            )
        }
    }
    
    func startLocalPlaybackPoller() async {
        if self.localPlaybackPoller == nil {
            self.localPlaybackPoller = startPoller(
                timeInterval: LOCAL_PLAYBACK_POLLER_INTERVAL,
                action: localPlaybackPollerAction
            )
        }
    }
    
    func startRemotePlaybackPoller() async {
        if self.remotePlaybackPoller == nil {
            self.remotePlaybackPoller = startPoller(
                timeInterval: REMOTE_PLAYBACK_POLLER_INTERVAL,
                action: remotePlaybackPollerAction
            )
        }
    }
    
    // TODO: error handling
    
    // TODO: account for actor re-entrancy / enforce ordering of concurrent requests
    // (practically, should be okay since all poll rates are low)
    
    private func remoteDevicesPollerAction() async {
        do {
            for availableDevice in try await Remote.fetchAvailableDevices().devices {
                let info = AvailableDeviceInfo(availableDevice: availableDevice)
                self.availableDevices[info] = availableDevice.id
            }
        } catch {
            print("[Spotify::PlaybackManager] (remote devices poller) failed to fetch available devices")
        }
    }
    
    // TODO: account for redundant increment whenever this runs immediately after a `remotePlaybackPollerAction`
    private func localPlaybackPollerAction() async {
        if self.isPlaying,
           let currentAudioTrack = self.currentTrack?.audioTrack
        {
            let intervalMilliseconds = LOCAL_PLAYBACK_POLLER_INTERVAL * 1000
            if self.positionMilliseconds + intervalMilliseconds < Double(currentAudioTrack.duration_ms) {
                self.positionMilliseconds += intervalMilliseconds
            } else {
                self.remotePlaybackPoller?.fire()
            }
        }
    }
    
    private func remotePlaybackPollerAction() async {
        do {
            let remoteState = try await Remote.fetchState()
            
            if !self.isRequestingRemoteSeek {
                self.positionMilliseconds = max(Double(remoteState.progress_ms ?? 0), POSITION_MS_SLIDER_MIN)
            }
            
            self.isPlaying = remoteState.is_playing
            
            switch self.context {
            case .remote(uri: let uri):
                if uri != remoteState.context?.uri {
                    self.context = .remote(uri: remoteState.context?.uri)
                }
                if let remoteAudioTrack = remoteState.item {
                    if self.currentTrack != .init(audioTrack: remoteAudioTrack) {
                        self.currentTrack = .init(audioTrack: remoteAudioTrack)
                    }
                } else {
                    self.currentTrack = nil
                }
                if self.repeatState != .init(remoteRepeatState: remoteState.repeat_state) {
                    self.repeatState = .init(remoteRepeatState: remoteState.repeat_state)
                }
            
            case .local(context: let context):
                if remoteState.repeat_state == .off && remoteState.context == nil {
                    // Remote state reflects that local control is currently being maintained,
                    // so we don't need to do anything other than play the next track in the local
                    // context at the appropriate time.
                    if !remoteState.is_playing && (remoteState.progress_ms ?? 0) == 0 {
                        await playNextInLocalContext()
                    }
                } else {
                    // Remote has taken the reins from local control.
                    self.context = .remote(uri: remoteState.context?.uri)
                    if let remoteAudioTrack = remoteState.item {
                        self.currentTrack = .init(audioTrack: remoteAudioTrack)
                    } else {
                        self.currentTrack = nil
                    }
                    self.repeatState = .init(remoteRepeatState: remoteState.repeat_state)
                }
            }
            
            let activeDeviceInfo = AvailableDeviceInfo(availableDevice: remoteState.device)
            if self.activeDevice != activeDeviceInfo {
                self.activeDevice = activeDeviceInfo
            }
            self.availableDevices[activeDeviceInfo] = remoteState.device.id
        }
        catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 204 {
            self.isPlaying = false
            self.activeDevice = nil
            // TODO: clear entirety of this view model?
        }
        catch {
            print("[Spotify::PlaybackManager] (remote playback poller) unexpected error")
            print(error.localizedDescription)
        }
    }
    
    private func playNextInLocalContext() async {
        
    }
}

// MARK: - Spotify Web API interface

private extension SpotifyPlaybackManager {
    struct Remote {
        private init() {} // namespace
        
        struct PlaybackState: Decodable {
            let device: AvailableDevice
            let repeat_state: RepeatState
            let shuffle_state: Bool
            let context: Context?
//            let timestamp: Int // timestamp of data fetch
            let progress_ms: Int?
            let is_playing: Bool
            let item: Spotify.AudioTrack?
            let currently_playing_type: CurrentlyPlayingType
            
            enum RepeatState: String, Decodable {
                case off, track, context
            }
            
            struct Context: Decodable {
                // TODO: enumify? need to handle unknown cases though
                let type: String // e.g. "artist", "playlist", "album", "show", etc.
//                let href: String
//                let external_urls
                let uri: String
            }
            
            enum CurrentlyPlayingType: String, Decodable {
                case track, episode, ad, unknown
            }
        }
        
        struct AvailableDevice: Decodable {
            let id: String?
//            let is_active: Bool // defer to polling playback state
//            let is_private_session: Bool
            let is_restricted: Bool
            let name: String
            let type: String
//            let volume_percent: Int?
//            let supports_volume: Bool
        }
        
        struct AllAvailableDevices: Decodable {
            let devices: [AvailableDevice]
        }
        
        private typealias HTTPMethod = SpotifyRequests.HTTPMethod
        
        static func fetchState() async throws -> PlaybackState {
            return try await SpotifyRequests.makeRequest(
                type: .GET,
                url: URL(string: "https://api.spotify.com/v1/me/player")!
            )
        }
        
        static func fetchAvailableDevices() async throws -> AllAvailableDevices {
            return try await SpotifyRequests.makeRequest(
                type: .GET,
                url: URL(string: "https://api.spotify.com/v1/me/player/devices")!
            )
        }
        
        static func startSingle(audioTrackID: String) async throws {
            struct StartSingleRequest: Encodable {
                let uris: [String]
            }
            
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/play")!,
                jsonBody: JSONEncoder().encode(
                    StartSingleRequest(
                        uris: ["spotify:track:\(audioTrackID)"]
                    )
                )
            )
        }
        
        static func startInContext(contextURI: String, contextOffset: Int) async throws {
            struct StartInContextRequest: Encodable {
                let context_uri: String
                let offset: Position
                
                struct Position: Encodable {
                    let position: Int
                }
            }
            
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/play")!,
                jsonBody: JSONEncoder().encode(
                    StartInContextRequest(
                        context_uri: contextURI,
                        offset: .init(position: contextOffset)
                    )
                )
            )
        }
        
        static func resume() async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/play")!
            )
        }
        
        static func pause() async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/pause")!
            )
        }
        
        static func skipToNext() async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .POST,
                url: URL(string: "https://api.spotify.com/v1/me/player/next")!
            )
        }
        
        static func skipToPrevious() async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .POST,
                url: URL(string: "https://api.spotify.com/v1/me/player/previous")!
            )
        }
        
        // TODO: clean up rest of these
        
        static func seek(positionMilliseconds: Int) async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/seek?position_ms=\(positionMilliseconds)")!
            )
        }
        
        static func setRepeatMode(state: PlaybackState.RepeatState) async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/repeat?state=\(state.rawValue)")!
            )
        }
        
        static func setShuffle(state: Bool) async throws {
            // lol
            if state {
                let _ = try await SpotifyRequests.makeRequest(
                    type: .PUT,
                    url: URL(string: "https://api.spotify.com/v1/me/player/shuffle?state=true")!
                )
            } else {
                let _ = try await SpotifyRequests.makeRequest(
                    type: .PUT,
                    url: URL(string: "https://api.spotify.com/v1/me/player/shuffle?state=false")!
                )
            }
        }
    }
}
