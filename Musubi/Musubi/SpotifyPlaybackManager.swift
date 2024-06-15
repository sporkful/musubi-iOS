// SpotifyPlaybackManager.swift

import Foundation

// TODO: remember playback state at quit?
// TODO: resolve redundant/conflicting notions of context between AudioTrackList and PlaybackManager

@Observable
@MainActor
class SpotifyPlaybackManager {
    var activeDeviceIndex: Int? // index into `self.availableDevices`
    
    private(set) var availableDevices: [AvailableDevice]
    private(set) var isPlaying: Bool
    private(set) var currentTrack: Musubi.ViewModel.AudioTrack?
    private(set) var context: Context
    private(set) var repeatState: LocalRepeatState
    private(set) var shuffle: Bool
    private(set) var positionMilliseconds: Double // needs to be double type for SwiftUI Slider
    
    let POSITION_MS_SLIDER_MIN = 10.0
    
    // Used to prevent remote state poller from updating position/slider with stale info.
    private var isRequestingRemoteSeek: Bool
    
    // TODO: better way to manage this? note adding as assoc-value to Context.local hurts UI (extra rerendering)
    // Used if the current context is .local and `self.currentTrack` gets concurrently removed from
    // the associated audioTrackList.
    private var backupCurrentIndex: Int?
    
    enum Context: Equatable {
        case local(audioTrackList: Musubi.ViewModel.AudioTrackList)
        case remote(audioTrackList: Musubi.ViewModel.AudioTrackList?)
        
        static func == (lhs: SpotifyPlaybackManager.Context, rhs: SpotifyPlaybackManager.Context) -> Bool {
            // Avoid using `default` so cases added in the future will be forced to be implemented.
            switch (lhs, rhs) {
            case (let .local(lhsAudioTrackList), let .local(rhsAudioTrackList)):
                lhsAudioTrackList.context.id == rhsAudioTrackList.context.id
            case (let .remote(lhsAudioTrackList), let .remote(rhsAudioTrackList)):
                lhsAudioTrackList?.context.id == rhsAudioTrackList?.context.id
            case (.local, .remote):
                false
            case (.remote, .local):
                false
            }
        }
    }
    
    enum LocalRepeatState: Equatable {
        case off, track, context
        
        var nextInToggle: LocalRepeatState {
            switch self {
                case .off: .context
                case .context: .track
                case .track: .off
            }
        }
        
        fileprivate init(remoteRepeatState: Remote.PlaybackState.RepeatState) {
            self = switch remoteRepeatState {
                case .off: .off
                case .track: .track
                case .context: .context
            }
        }
    }
    
    // TODO: enumify type? need to handle unknown cases though
    struct AvailableDevice: Decodable, Equatable {
        let id: String?
//        let is_active: Bool // defer to polling playback state
//        let is_private_session: Bool
        let is_restricted: Bool
        let name: String
        let type: String // e.g. "Computer", "Smartphone", "Speaker", etc.
//        let volume_percent: Int?
//        let supports_volume: Bool
        
        var sfSymbolName: String {
            switch self.type {
                case "Smartphone": "smartphone"
                case "Computer": "desktopcomputer"
                case "Speaker": "hifispeaker"
                default: "speaker.square"
            }
        }
    }
    
    init() {
        self.activeDeviceIndex = nil
        self.availableDevices = []
        self.isPlaying = false
        self.currentTrack = nil
        self.context = .remote(audioTrackList: nil)
        self.repeatState = .context
        self.shuffle = false
        self.positionMilliseconds = 0
        self.isRequestingRemoteSeek = false
        self.backupCurrentIndex = nil
        
        Task {
            await startRemotePlaybackPoller()
            await startLocalPlaybackPoller()
        }
    }
    
    private var remotePlaybackPoller: Timer? = nil // polls Spotify for actual current playback state
    private var localPlaybackPoller: Timer? = nil // interpolates self.position between remotePlaybackPoller firings
    
    // in seconds
    private let REMOTE_PLAYBACK_POLLER_INTERVAL: TimeInterval = 5.0 // kept high to stay within Spotify rate limits
    private let LOCAL_PLAYBACK_POLLER_INTERVAL: TimeInterval = 1.0
    
    private var ignoreRemoteStateBefore: Date = Date.distantPast
    
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
            
            if Date.now < self.ignoreRemoteStateBefore {
                print("[SpotifyPlaybackManager] note intentionally ignored remote playback state")
                return
            }
            
            if !self.isRequestingRemoteSeek {
                self.positionMilliseconds = max(Double(remoteState.progress_ms ?? 0), POSITION_MS_SLIDER_MIN)
            }
            
            self.isPlaying = remoteState.is_playing
            
            switch self.context {
            case let .remote(audioTrackList):
                // Avoid unnecessarily rerendering heavyweight view components.
                // TODO: clean these up
                var wasContextUpdated = false
                if audioTrackList?.context.uri != remoteState.context?.uri {
                    if let remoteContext = remoteState.context,
                       let contextID = Optional(String(remoteContext.uri.split(separator: ":")[2])),
                       let newAudioTrackList: Musubi.ViewModel.AudioTrackList = switch remoteContext.type {
                           case "album": .init(albumMetadata: try await SpotifyRequests.Read.albumMetadata(albumID: contextID))
                           case "playlist": .init(playlistMetadata: try await SpotifyRequests.Read.playlistMetadata(playlistID: contextID))
                           case "artist": .init(artistMetadata: try await SpotifyRequests.Read.artistMetadata(artistID: contextID))
                           default: nil
                       }
                    {
                        self.context = .remote(audioTrackList: newAudioTrackList)
                        try await newAudioTrackList.initialHydrationTask.value
                    } else {
                        self.context = .remote(audioTrackList: nil)
                    }
                    wasContextUpdated = true
                }
                
                if let remoteAudioTrack = remoteState.item {
                    if self.currentTrack?.audioTrackID != remoteAudioTrack.id {
                        if !wasContextUpdated,
                           let audioTrackList = audioTrackList,
                           let currentTrack = self.currentTrack,
                           let currentTrackIndex = audioTrackList.contents.firstIndex(of: currentTrack)
                        {
                            let expectedNextTrackIndex = min(currentTrackIndex + 1, audioTrackList.contents.count) % audioTrackList.contents.count
                            if audioTrackList.contents[expectedNextTrackIndex].audioTrackID == remoteAudioTrack.id {
                                self.currentTrack = audioTrackList.contents[expectedNextTrackIndex]
                            } else {
                                self.currentTrack = audioTrackList.contents.first(where: { $0.audioTrackID == remoteAudioTrack.id })
                                    ?? .init(audioTrack: remoteAudioTrack)
                            }
                        }
                        else {
                            if case .remote(let audioTrackList) = self.context,
                               let audioTrackList = audioTrackList
                            {
                                self.currentTrack = audioTrackList.contents.first(where: { $0.audioTrackID == remoteAudioTrack.id })
                                    ?? .init(audioTrack: remoteAudioTrack)
                            } else {
                                self.currentTrack = .init(audioTrack: remoteAudioTrack)
                            }
                        }
                    }
                } else {
                    self.currentTrack = nil
                }
                
                self.repeatState = .init(remoteRepeatState: remoteState.repeat_state)
                self.shuffle = remoteState.shuffle_state
            
            case .local:
                if remoteState.repeat_state == .off && remoteState.context == nil {
                    // Remote state reflects that local control is currently being maintained,
                    // so we don't need to do anything other than play the next track in the local
                    // context at the appropriate time.
                    if !remoteState.is_playing && (remoteState.progress_ms ?? 0) == 0 {
                        try await playNextInLocalContext()
                    }
                } else {
                    // Remote has taken the reins from local control.
                    if let remoteContext = remoteState.context,
                       let contextID = Optional(String(remoteContext.uri.split(separator: ":")[2])),
                       let newAudioTrackList: Musubi.ViewModel.AudioTrackList = switch remoteContext.type {
                           case "album": .init(albumMetadata: try await SpotifyRequests.Read.albumMetadata(albumID: contextID))
                           case "playlist": .init(playlistMetadata: try await SpotifyRequests.Read.playlistMetadata(playlistID: contextID))
                           case "artist": .init(artistMetadata: try await SpotifyRequests.Read.artistMetadata(artistID: contextID))
                           default: nil
                       }
                    {
                        self.context = .remote(audioTrackList: newAudioTrackList)
                        try await newAudioTrackList.initialHydrationTask.value
                    } else {
                        self.context = .remote(audioTrackList: nil)
                    }
                    if let remoteAudioTrack = remoteState.item {
                        if case .remote(let audioTrackList) = self.context,
                           let audioTrackList = audioTrackList
                        {
                            self.currentTrack = audioTrackList.contents.first(where: { $0.audioTrackID == remoteAudioTrack.id })
                                ?? .init(audioTrack: remoteAudioTrack)
                        } else {
                            self.currentTrack = .init(audioTrack: remoteAudioTrack)
                        }
                    } else {
                        self.currentTrack = nil
                    }
                    self.backupCurrentIndex = nil
                    self.repeatState = .init(remoteRepeatState: remoteState.repeat_state)
                    self.shuffle = remoteState.shuffle_state
                }
            }
            
            print()
            print("currentTrack:")
            print("name: \(String(describing: self.currentTrack?.audioTrack.name))")
            print("occurrence: \(String(describing: self.currentTrack?.occurrence))")
            print("context: \(String(describing: self.currentTrack?.parent?.context.name))")
            
            guard let updatedActiveDeviceIndex = self.availableDevices.firstIndex(of: remoteState.device) else {
                try await updateAvailableDevices()
                return
                // `self.activeDeviceIndex` will be updated on next firing.
            }
            if self.activeDeviceIndex != updatedActiveDeviceIndex {
                self.activeDeviceIndex = updatedActiveDeviceIndex
            }
        }
//        catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 204 {
        catch is DecodingError {
            print("[\(Date.now.formatted())] detected playback not active")
            
            self.isPlaying = false
            self.activeDeviceIndex = nil
            // TODO: clear entirety of this view model?
        }
        catch {
            print("[Spotify::PlaybackManager] (remote playback poller) unexpected error")
            print(error.localizedDescription)
        }
    }
    
    private func playNextInLocalContext() async throws {
        guard case .local(let audioTrackList) = self.context else {
            throw CustomError.DEV(detail: "(playNextInLocalContext) called when current context is remote")
        }
        
        // TODO: better typing to encode what counts as a local context
        switch audioTrackList.context {
        case is Spotify.AlbumMetadata, is Spotify.PlaylistMetadata, is Spotify.ArtistMetadata, is Spotify.AudioTrack:
            throw CustomError.DEV(detail: "(playNextInLocalContext) local audioTrackList context should be remote")
        case is Musubi.RepositoryReference, is Musubi.RepositoryCommit:
            break
        default:
            throw CustomError.DEV(detail: "(playNextInLocalContext) unrecognized AudioTrackListContext type")
        }
        
        guard let currentTrack = currentTrack else {
            throw CustomError.DEV(detail: "(playNextInLocalContext) called with nil current track")
        }
        
        self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
        
        switch self.repeatState {
        case .track:
            try await Remote.startSingle(audioTrackID: currentTrack.audioTrackID)
            self.positionMilliseconds = 0
            self.isPlaying = true
        case .context, .off:
            let nextTrackIndex: Int
            if self.shuffle {
                nextTrackIndex = Int.random(in: audioTrackList.contents.indices)
            } else {
                // TODO: improve perf by redesigning ViewModel::AudioTrackList?
                let currentTrackIndex = audioTrackList.contents.firstIndex(of: currentTrack) ?? backupCurrentIndex ?? -1
                nextTrackIndex = min(currentTrackIndex + 1, audioTrackList.contents.count) % audioTrackList.contents.count
                if self.repeatState == .off && currentTrackIndex == (audioTrackList.contents.endIndex - 1) {
                    break
                }
            }
            let nextTrack = audioTrackList.contents[nextTrackIndex]
            try await Remote.startSingle(audioTrackID: nextTrack.audioTrackID)
            self.currentTrack = nextTrack
            self.backupCurrentIndex = nextTrackIndex
            self.positionMilliseconds = 0
            self.isPlaying = true
        }
    }
    
    // MARK: - user-accessible functions
    
    static var PLAY_ERROR_MESSAGE: String {
        if Musubi.UserManager.shared.currentUser?.spotifyInfo.product == "premium" {
            """
            Select a device to use for playback in the "My Account" tab. Note that a device must have \
            the official Spotify app or web-player open in the background in order to be considered \
            available for playback.
            """
        } else {
            """
            Unfortunately, Spotify's API does not support playback control for non-premium users \
            at this time. Note that you can still control playback in the official Spotify apps and \
            view the currently-playing track in the Musubi app.
            """
        }
    }
    
    // Assumes audioTrackListElement is a valid element of its parent AudioTrackList::contents (if non-nil).
    // This assumption holds by further assuming the function is only called from ListCell<ViewModel.AudioTrack>
    // (as a result of direct user input/tap).
    func play(audioTrackListElement: Musubi.ViewModel.AudioTrack) async throws {
        self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
        
        guard let audioTrackList = audioTrackListElement.parent else {
            try await Remote.startSingle(audioTrackID: audioTrackListElement.audioTrackID)
            self.currentTrack = audioTrackListElement
            self.context = .remote(audioTrackList: nil)
            self.backupCurrentIndex = nil
            self.positionMilliseconds = 0
            self.isPlaying = true
            return
        }
        
        // TODO: better typing to encode what counts as a local context
        switch audioTrackList.context {
        case is Spotify.AlbumMetadata, is Spotify.PlaylistMetadata, is Spotify.ArtistMetadata:
            try await Remote.startInContext(
                contextURI: audioTrackList.context.uri,
                contextOffset: audioTrackList.contents.firstIndex(of: audioTrackListElement) ?? 0
            )
            self.currentTrack = audioTrackListElement
            self.context = .remote(audioTrackList: audioTrackList)
            self.backupCurrentIndex = nil
            self.positionMilliseconds = 0
            self.isPlaying = true
        
        case is Spotify.AudioTrack:
            try await Remote.startSingle(audioTrackID: audioTrackListElement.audioTrackID)
            self.currentTrack = audioTrackListElement
            self.context = .remote(audioTrackList: nil)
            self.backupCurrentIndex = nil
            self.positionMilliseconds = 0
            self.isPlaying = true
        
        case is Musubi.RepositoryReference, is Musubi.RepositoryCommit:
            try await Remote.setRepeatMode(state: .off)
            try await Remote.startSingle(audioTrackID: audioTrackListElement.audioTrackID)
            let index = audioTrackList.contents.firstIndex(of: audioTrackListElement)!
            self.currentTrack = audioTrackListElement
            self.context = .local(audioTrackList: audioTrackList)
            self.backupCurrentIndex = index
            self.positionMilliseconds = 0
            self.isPlaying = true
        
        default:
            throw CustomError.DEV(detail: "(play) unrecognized AudioTrackListContext type")
        }
    }
    
    func pause() async throws {
        try await Remote.pause()
        self.isPlaying = false
    }
    
    func resume() async throws {
        try await Remote.resume()
        self.isPlaying = true
    }
    
    func skipToNext() async throws {
        switch self.context {
        case .remote:
            try await Remote.skipToNext()
            self.remotePlaybackPoller?.fire()
            
        case .local:
            if self.repeatState == .track {
                self.repeatState = .context
            }
            try await playNextInLocalContext()
        }
    }
    
    func skipToPrevious() async throws {
        switch self.context {
        case .remote:
            try await Remote.skipToPrevious()
            self.remotePlaybackPoller?.fire()
            
        case let .local(audioTrackList):
            guard let currentTrack = currentTrack else {
                throw CustomError.DEV(detail: "(skipToPrevious) called with nil current track")
            }
            
            self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
            
            if self.repeatState == .track {
                self.repeatState = .context
            }
            
            let previousTrackIndex: Int
            if self.shuffle {
                // TODO: use recently played? (note no need to distinguish between duplicate tracks if in shuffle)
                previousTrackIndex = Int.random(in: audioTrackList.contents.indices)
            } else {
                // TODO: improve perf by redesigning ViewModel::AudioTrackList?
                let currentTrackIndex = audioTrackList.contents.firstIndex(of: currentTrack) ?? backupCurrentIndex ?? 0
                if currentTrackIndex == 0 {
                    if self.repeatState == .off {
                        previousTrackIndex = currentTrackIndex
                    } else {
                        previousTrackIndex = audioTrackList.contents.endIndex - 1
                    }
                } else {
                    previousTrackIndex = currentTrackIndex - 1
                }
            }
            let previousTrack = audioTrackList.contents[previousTrackIndex]
            try await Remote.startSingle(audioTrackID: previousTrack.audioTrackID)
            self.currentTrack = previousTrack
            self.backupCurrentIndex = previousTrackIndex
            self.positionMilliseconds = 0
            self.isPlaying = true
        }
    }
    
    func toggleRepeatState() async throws {
        let setState = self.repeatState.nextInToggle
        if case .remote = self.context {
            try await Remote.setRepeatMode(state: .init(localRepeatState: setState))
        }
        self.repeatState = setState
    }
    
    func toggleShuffle() async throws {
        let setState = !self.shuffle
        if case .remote = self.context {
            try await Remote.setShuffle(state: setState)
        }
        self.shuffle = setState
    }
    
    // Assumes UI has already updated `self.positionMilliseconds`.
    func seek(toPositionMilliseconds: Double) async throws {
        self.isRequestingRemoteSeek = true
        try await Remote.seek(toPositionMilliseconds: Int(toPositionMilliseconds))
        self.isRequestingRemoteSeek = false
    }
    
    func updateAvailableDevices() async throws {
        let updatedAvailableDevices = try await Remote.fetchAvailableDevices().devices
        if self.availableDevices != updatedAvailableDevices {
            self.activeDeviceIndex = nil
            self.availableDevices = updatedAvailableDevices
            self.remotePlaybackPoller?.fire() // to update `self.activeDeviceIndex`
        }
    }
    
    func transferPlaybackTo(deviceID: String) async throws {
        try await Remote.transferPlaybackTo(deviceID: deviceID)
    }
    
    func resetOnLossOfActiveDevice() async throws {
        // Note this function is attached to onChange listeners for `self.activeDeviceIndex = nil`,
        // so avoid setting it in infinite recursion.
        
        self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
        
//        self.activeDeviceIndex = nil
//        self.availableDevices = []
        self.isPlaying = false
        self.currentTrack = nil
        self.context = .remote(audioTrackList: nil)
        self.repeatState = .context
        self.shuffle = false
        self.positionMilliseconds = 0
        self.isRequestingRemoteSeek = false
        self.backupCurrentIndex = nil
    }
    
    enum CustomError: LocalizedError {
        case DEV(detail: String)

        var errorDescription: String? {
            let description = switch self {
                case let .DEV(detail): "(DEV) \(detail)"
            }
            return "[Spotify::PlaybackManager] \(description)"
        }
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
//            let timestamp: Int // Spotify's timestamp of last modification of non-progress_ms playback state
            let progress_ms: Int?
            let is_playing: Bool
            let item: Spotify.AudioTrack?
            let currently_playing_type: CurrentlyPlayingType
            
            enum RepeatState: String, Decodable {
                case off, track, context
                
                init(localRepeatState: LocalRepeatState) {
                    self = switch localRepeatState {
                        case .off: .off
                        case .track: .track
                        case .context: .context
                    }
                }
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
        
        static func seek(toPositionMilliseconds: Int) async throws {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/seek?position_ms=\(toPositionMilliseconds)")!
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
        
        static func transferPlaybackTo(deviceID: String) async throws {
            struct DeviceIDs: Encodable {
                let device_ids: [String]
            }
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player")!,
                jsonBody: JSONEncoder().encode(DeviceIDs(device_ids: [deviceID]))
            )
        }
    }
}
