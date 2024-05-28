// SpotifyPlaybackManager.swift

import Foundation

@Observable
@MainActor
class SpotifyPlaybackManager {
    private(set) var availableDevices: [SpotifyAvailableDevice]
    private(set) var activeDevice: SpotifyAvailableDevice?
    private(set) var isPlaying: Bool
    private(set) var currentTrack: Musubi.ViewModel.AudioTrackList.UniquifiedElement?
    private(set) var context: Context
    private(set) var repeatState: LocalRepeatState
    private(set) var positionMilliseconds: Double // needs to be double type for SwiftUI Slider
    
    // Used to prevent conflicting concurrent remote-seek-requests when user is scrubbing.
    var isRequestingRemoteSeek: Bool
    
    enum Context: Equatable {
        case local(context: (any AudioTrackListContext)?)
        case remote(uri: String)
        
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
    }
    
    struct SpotifyAvailableDevice: Decodable {
        let id: String?
        let is_active: Bool
//        let is_private_session: Bool
//        let is_restricted: Bool
        let name: String
        let type: String // e.g. "computer", "smartphone", "speaker", etc. // TODO: enumify?
//        let volume_percent: Int?
//        let supports_volume: Bool
    }
    
    init() {
        self.availableDevices = []
        self.activeDevice = nil
        self.isPlaying = false
        self.currentTrack = nil
        self.context = .local(context: nil)
        self.repeatState = .context
        self.positionMilliseconds = 0
        self.isRequestingRemoteSeek = false
        
        Task {
            await startRemoteDevicesPoller()
            await startRemotePlaybackPoller()
//            await startLocalPlaybackPoller()
        }
    }
    
    private var remoteDevicesPoller: Timer? = nil
    private var remotePlaybackPoller: Timer? = nil
//    private var localPlaybackPoller: Timer? = nil // for if remote polling hits Spotify rate limit
    
    // in seconds
    private let REMOTE_DEVICES_POLLER_INTERVAL: TimeInterval = 5 * 60.0
    private let REMOTE_PLAYBACK_POLLER_INTERVAL: TimeInterval = 1.0
//    private let LOCAL_PLAYBACK_POLLER_INTERVAL: TimeInterval = 1.0
    
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
    
    func startRemotePlaybackPoller() async {
        if self.remotePlaybackPoller == nil {
            self.remotePlaybackPoller = startPoller(
                timeInterval: REMOTE_PLAYBACK_POLLER_INTERVAL,
                action: remotePlaybackPollerAction
            )
        }
    }
    
//    func startLocalPlaybackPoller() async {
//        if self.localPlaybackPoller == nil {
//            self.localPlaybackPoller = startPoller(
//                timeInterval: LOCAL_PLAYBACK_POLLER_INTERVAL,
//                action: localPlaybackPollerAction
//            )
//        }
//    }
    
    // TODO: error handling
    
    // TODO: account for actor re-entrancy / enforce ordering of concurrent requests
    // (practically, should be okay since all poll rates are low)
    
    private func remoteDevicesPollerAction() async {
        do {
            self.availableDevices = try await Remote.fetchAvailableDevices().devices
        } catch {
            print("[Spotify::PlaybackManager] (remote devices poller) failed to fetch available devices")
        }
    }
    
    private func remotePlaybackPollerAction() async {
        
        // TODO: at end, fire low priority task that also updates self.availableDevices with current device info,
        // specifically non-persistent ID/name
    }
}

// MARK: - Spotify Web API interface

private extension SpotifyPlaybackManager {
    struct Remote {
        private init() {} // namespace
        
        struct PlaybackState: Decodable {
            let device: SpotifyAvailableDevice
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
        
        struct AllAvailableDevices: Decodable {
            let devices: [SpotifyAvailableDevice]
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
