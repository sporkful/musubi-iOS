// SpotifyPlaybackManager.swift

import Foundation

// TODO: remember some of playback state at quit / loss of active device?
// TODO: resolve redundant/conflicting notions of context between AudioTrackList and PlaybackManager

@Observable
@MainActor
class SpotifyPlaybackManager {
    var desiredActiveDevice: AvailableDevice?
    
    private(set) var availableDevices: [AvailableDevice]
    private(set) var isPlaying: Bool
    private(set) var currentTrack: Musubi.ViewModel.AudioTrack?
    private(set) var context: Context
    private(set) var repeatState: LocalRepeatState
    private(set) var shuffle: Bool
    
    // TODO: better way to do this?
    // Note if we made this private(set), we wouldn't be able to make a SwiftUI Binding to it
    // (custom Bindings don't work either since this is an actor-isolated async property),
    // which is necessary for the Slider component in PlayerSheet. However, we still follow
    // private(set) semantics - edits from the Slider are routed to an isolated function in this class.
    var positionMilliseconds: Double // needs to be type Double for SwiftUI Slider
    
    static let POSITION_MS_SLIDER_MIN: Double = 10.0
    
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
        
        fileprivate init(remoteRepeatState: RemotePlaybackState.RepeatState) {
            self = switch remoteRepeatState {
                case .off: .off
                case .track: .track
                case .context: .context
            }
        }
    }
    
    // TODO: enumify type? need to handle unknown cases though
    struct AvailableDevice: Decodable, Equatable, Hashable {
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
    
    var showAlertNoDevice: Bool = false
    var showAlertOpenSpotifyOnTargetDevice: Bool = false
    
    var NO_DEVICE_ERROR_MESSAGE: String {
        if Musubi.UserManager.shared.currentUser?.spotifyInfo.product == "premium" {
            """
            Select a device to use for playback in the "My Account" tab.
            """
        } else {
            """
            Unfortunately, Spotify's API does not support playback control for non-premium users \
            at this time. You can still control playback in the official Spotify apps and view the \
            currently-playing track in the Musubi app.
            """
        }
    }
    
    init() {
        self.desiredActiveDevice = nil
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
    
    private var localPlaybackPollerLastReference: Date? = nil
    
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
                action: { await self.remotePlaybackPollerAction() }
            )
        }
    }
    
    // TODO: error handling
    
    // TODO: account for actor re-entrancy / enforce ordering of concurrent requests
    // (practically, should be okay since all poll rates are low)
    
    private func localPlaybackPollerAction() async {
        if self.isPlaying,
           !self.isRequestingRemoteSeek,
           let currentAudioTrack = self.currentTrack?.audioTrack
        {
            let newReference: Date = Date.now
            let intervalMilliseconds: Double
            if let lastReference = self.localPlaybackPollerLastReference {
                intervalMilliseconds = newReference.timeIntervalSince(lastReference) * 1000
            } else {
                intervalMilliseconds = 0
            }
            self.localPlaybackPollerLastReference = newReference
            
            if self.positionMilliseconds + intervalMilliseconds < Double(currentAudioTrack.duration_ms) {
                self.positionMilliseconds += intervalMilliseconds
            } else {
                self.remotePlaybackPoller?.fire()
            }
        }
    }
    
    func remotePlaybackPollerAction(overrideIgnore: Bool = false) async {
        do {
            let remoteState = try await remoteFetchState()
            let responseTimestamp = Date.now
            
            if !overrideIgnore && (responseTimestamp < self.ignoreRemoteStateBefore) {
                print("[SpotifyPlaybackManager] note intentionally ignored remote playback state")
                return
            }
            
            switch self.context {
            case let .remote(audioTrackList):
                // Avoid unnecessarily rerendering heavyweight view components.
                // TODO: clean these up
                var wasContextUpdated = false
                if audioTrackList?.context.uri != remoteState.context?.uri
                    || (remoteState.context != nil && self.currentTrack?.parent?.context == nil)
                {
                    if let remoteContext = remoteState.context,
                       let contextID = Optional(String(remoteContext.uri.split(separator: ":")[2])),
                       let newAudioTrackList: Musubi.ViewModel.AudioTrackList = switch remoteContext.type {
                           case "album": .init(albumMetadata: try await SpotifyRequests.Read.albumMetadata(albumID: contextID))
                           case "playlist": .init(playlistMetadata: try await SpotifyRequests.Read.playlistMetadata(playlistID: contextID))
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
                    if self.currentTrack?.audioTrackID != remoteAudioTrack.id
                        || wasContextUpdated
                    {
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
                        return
                    }
                } else {
                    // Remote has taken the reins from local control.
                    if let remoteContext = remoteState.context,
                       let contextID = Optional(String(remoteContext.uri.split(separator: ":")[2])),
                       let newAudioTrackList: Musubi.ViewModel.AudioTrackList = switch remoteContext.type {
                           case "album": .init(albumMetadata: try await SpotifyRequests.Read.albumMetadata(albumID: contextID))
                           case "playlist": .init(playlistMetadata: try await SpotifyRequests.Read.playlistMetadata(playlistID: contextID))
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
            
            self.isPlaying = remoteState.is_playing
            
            if !self.isRequestingRemoteSeek {
                self.positionMilliseconds = max(Double(remoteState.progress_ms ?? 0), SpotifyPlaybackManager.POSITION_MS_SLIDER_MIN)
                
                if self.isPlaying {
                    let now: Date = Date.now
                    self.positionMilliseconds += (now.timeIntervalSince(responseTimestamp) * 1000)
                    self.localPlaybackPollerLastReference = now
                } else {
                    self.localPlaybackPollerLastReference = nil
                }
            }
            
            // remove stale device IDs
            self.availableDevices.removeAll(
                where: {
                    $0.name == remoteState.device.name
                        && $0.type == remoteState.device.type
                        && $0.id != remoteState.device.id
                }
            )
            
            if !self.availableDevices.contains(remoteState.device) {
                try await updateAvailableDevices()
            }
            
            if self.desiredActiveDevice != remoteState.device {
                self.desiredActiveDevice = remoteState.device
            }
        }
//        catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 204 {
        catch is DecodingError {
            print("[\(Date.now.formatted())] detected playback not active")
            
            // Since Spotify's playback API doesn't work on iOS if Spotify is in the background, we
            // don't invalidate desiredActiveDevice.
//            self.desiredActiveDevice = nil
//            await self.resetOnLossOfActiveDevice()
        }
        catch {
            print("[Spotify::PlaybackManager] (remote playback poller) unexpected error")
            print(error.localizedDescription)
        }
    }
    
    private func playNextInLocalContext() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        guard case .local(let audioTrackList) = self.context else {
            throw CustomError.DEV(detail: "(playNextInLocalContext) called when current context is remote")
        }
        
        // TODO: better typing to encode what counts as a local context
        switch audioTrackList.context {
        case is Spotify.AlbumMetadata, is Spotify.PlaylistMetadata, is Spotify.AudioTrack:
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
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartSingle(audioTrackID: currentTrack.audioTrackID, desiredActiveDeviceID: desiredActiveDeviceID)
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
            self.currentTrack = nextTrack
            self.backupCurrentIndex = nextTrackIndex
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartSingle(audioTrackID: nextTrack.audioTrackID, desiredActiveDeviceID: desiredActiveDeviceID)
        }
    }
    
    // MARK: - user-accessible functions
    
    // Assumes audioTrack is a valid element of its parent AudioTrackList::contents (if non-nil).
    // This assumption holds by further assuming the function is only called from ListCell<ViewModel.AudioTrack>
    // (as a result of direct user input/tap).
    func play(audioTrack: Musubi.ViewModel.AudioTrack) async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
        
        // TODO: check this (afaik this is Spotify's behavior)
        if self.repeatState == .track {
            self.repeatState = .context
        }
        
        guard let audioTrackList = audioTrack.parent else {
            self.currentTrack = audioTrack
            self.context = .remote(audioTrackList: nil)
            self.backupCurrentIndex = nil
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartSingle(audioTrackID: audioTrack.audioTrackID, desiredActiveDeviceID: desiredActiveDeviceID)
            try await remoteSetRepeatMode(state: .init(localRepeatState: self.repeatState), desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
            try await remoteSetShuffle(state: self.shuffle, desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
            return
        }
        
        // TODO: better typing to encode what counts as a local context
        switch audioTrackList.context {
        case is Spotify.AlbumMetadata, is Spotify.PlaylistMetadata:
            self.currentTrack = audioTrack
            self.context = .remote(audioTrackList: audioTrackList)
            self.backupCurrentIndex = nil
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartInContext(
                contextURI: audioTrackList.context.uri,
                contextOffset: audioTrackList.contents.firstIndex(of: audioTrack) ?? 0, desiredActiveDeviceID: desiredActiveDeviceID
            )
            try await remoteSetRepeatMode(state: .init(localRepeatState: self.repeatState), desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
            try await remoteSetShuffle(state: self.shuffle, desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
        
        case is Spotify.AudioTrack:
            self.currentTrack = audioTrack
            self.context = .remote(audioTrackList: nil)
            self.backupCurrentIndex = nil
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartSingle(audioTrackID: audioTrack.audioTrackID, desiredActiveDeviceID: desiredActiveDeviceID)
            try await remoteSetRepeatMode(state: .init(localRepeatState: self.repeatState), desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
            try await remoteSetShuffle(state: self.shuffle, desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
        
        case is Musubi.RepositoryReference, is Musubi.RepositoryCommit:
            let index = audioTrackList.contents.firstIndex(of: audioTrack)!
            self.currentTrack = audioTrack
            self.context = .local(audioTrackList: audioTrackList)
            self.backupCurrentIndex = index
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartSingle(audioTrackID: audioTrack.audioTrackID, desiredActiveDeviceID: desiredActiveDeviceID)
            try await remoteSetRepeatMode(state: .off, desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
            try await remoteSetShuffle(state: self.shuffle, desiredActiveDeviceID: desiredActiveDeviceID, ignoreSpotifyOpenError: true)
        
        default:
            throw CustomError.DEV(detail: "(play) unrecognized AudioTrackListContext type")
        }
    }
    
    func pause() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        self.isPlaying = false
        try await remotePause(desiredActiveDeviceID: desiredActiveDeviceID)
        self.remotePlaybackPoller?.fire()
    }
    
    func resume() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        self.isPlaying = true
        try await remoteResume(desiredActiveDeviceID: desiredActiveDeviceID)
        self.remotePlaybackPoller?.fire()
    }
    
    func skipToNext() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        switch self.context {
        case .remote:
            try await remoteSkipToNext(desiredActiveDeviceID: desiredActiveDeviceID)
            self.remotePlaybackPoller?.fire()
            
        case .local:
            // TODO: check this (afaik this is Spotify's behavior)
            if self.repeatState == .track {
                self.repeatState = .context
            }
            try await playNextInLocalContext()
        }
    }
    
    func skipToPrevious() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        switch self.context {
        case .remote:
            try await remoteSkipToPrevious(desiredActiveDeviceID: desiredActiveDeviceID)
            self.remotePlaybackPoller?.fire()
            
        case let .local(audioTrackList):
            guard let currentTrack = currentTrack else {
                throw CustomError.DEV(detail: "(skipToPrevious) called with nil current track")
            }
            
            self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
            
            // TODO: check this (afaik this is Spotify's behavior)
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
            self.currentTrack = previousTrack
            self.backupCurrentIndex = previousTrackIndex
            self.positionMilliseconds = 0
            self.localPlaybackPollerLastReference = Date.now
            self.isPlaying = true
            try await remoteStartSingle(audioTrackID: previousTrack.audioTrackID, desiredActiveDeviceID: desiredActiveDeviceID)
        }
    }
    
    func toggleRepeatState() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        let setState = self.repeatState.nextInToggle
        self.repeatState = setState
        if case .remote = self.context {
            try await remoteSetRepeatMode(state: .init(localRepeatState: setState), desiredActiveDeviceID: desiredActiveDeviceID)
        }
    }
    
    func toggleShuffle() async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        let setState = !self.shuffle
        self.shuffle = setState
        if case .remote = self.context {
            try await remoteSetShuffle(state: setState, desiredActiveDeviceID: desiredActiveDeviceID)
        }
    }
    
    func seek(toPositionMilliseconds: Double) async throws {
        guard let desiredActiveDeviceID = self.desiredActiveDevice?.id else {
            self.showAlertNoDevice = true
            return
        }
        
        self.isRequestingRemoteSeek = true
        self.positionMilliseconds = toPositionMilliseconds
        try await remoteSeek(toPositionMilliseconds: Int(toPositionMilliseconds), desiredActiveDeviceID: desiredActiveDeviceID)
        self.localPlaybackPollerLastReference = nil
        self.isRequestingRemoteSeek = false
        self.remotePlaybackPoller?.fire()
    }
    
    func updateAvailableDevices() async throws {
        let updatedAvailableDevices = try await remoteFetchAvailableDevices().devices
        if self.availableDevices != updatedAvailableDevices {
            self.availableDevices = updatedAvailableDevices
        }
        
        // update stale device ID if needed
        if let desiredActiveDevice = self.desiredActiveDevice,
           let updatedActiveDevice = self.availableDevices.first(
                where: {
                    $0.name == desiredActiveDevice.name
                    && $0.type == desiredActiveDevice.type
                    && $0.id != desiredActiveDevice.id
                }
           )
        {
            self.desiredActiveDevice = updatedActiveDevice
        }
        
        if let desiredActiveDevice = self.desiredActiveDevice,
           !self.availableDevices.contains(desiredActiveDevice)
        {
            self.desiredActiveDevice = nil
            await resetOnLossOfActiveDevice()
        }
    }
    
    func resetOnLossOfActiveDevice() async {
        // Note this function is attached to onChange listeners for `self.desiredActiveDevice = nil`,
        // so avoid setting it in infinite recursion.
        
        self.ignoreRemoteStateBefore = Date.init(timeIntervalSinceNow: 5)
        
//        self.activeDeviceIndex = nil
//        self.availableDevices = []
        self.isPlaying = false
//        self.currentTrack = nil
//        self.context = .remote(audioTrackList: nil)
//        self.repeatState = .context
//        self.shuffle = false
//        self.positionMilliseconds = 0
//        self.isRequestingRemoteSeek = false
//        self.backupCurrentIndex = nil
        
        self.localPlaybackPollerLastReference = nil
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
        struct RemotePlaybackState: Decodable {
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
        
        struct RemoteAvailableDevices: Decodable {
            let devices: [AvailableDevice]
        }
        
        private typealias HTTPMethod = SpotifyRequests.HTTPMethod
        
        func remoteFetchState() async throws -> RemotePlaybackState {
            return try await SpotifyRequests.makeRequest(
                type: .GET,
                url: URL(string: "https://api.spotify.com/v1/me/player")!
            )
        }
        
        func remoteFetchAvailableDevices() async throws -> RemoteAvailableDevices {
            return try await SpotifyRequests.makeRequest(
                type: .GET,
                url: URL(string: "https://api.spotify.com/v1/me/player/devices")!
            )
        }
        
        func remoteStartSingle(audioTrackID: String, desiredActiveDeviceID: String) async throws {
            struct StartSingleRequest: Encodable {
                let uris: [String]
            }
            
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/play?device_id=\(desiredActiveDeviceID)")!,
                jsonBody: JSONEncoder().encode(
                    StartSingleRequest(
                        uris: ["spotify:track:\(audioTrackID)"]
                    )
                )
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        func remoteStartInContext(contextURI: String, contextOffset: Int?, desiredActiveDeviceID: String) async throws {
            struct StartInContextRequest: Encodable {
                let context_uri: String
                let offset: Position?
                
                struct Position: Encodable {
                    let position: Int
                    
                    init?(position: Int?) {
                        guard let position = position else {
                            return nil
                        }
                        self.position = position
                    }
                }
            }
            
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/play?device_id=\(desiredActiveDeviceID)")!,
                jsonBody: JSONEncoder().encode(
                    StartInContextRequest(
                        context_uri: contextURI,
                        offset: .init(position: contextOffset)
                    )
                )
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        func remoteResume(desiredActiveDeviceID: String) async throws {
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/play?device_id=\(desiredActiveDeviceID)")!
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        func remotePause(desiredActiveDeviceID: String) async throws {
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/pause?device_id=\(desiredActiveDeviceID)")!
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        func remoteSkipToNext(desiredActiveDeviceID: String) async throws {
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .POST,
                url: URL(string: "https://api.spotify.com/v1/me/player/next?device_id=\(desiredActiveDeviceID)")!
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        func remoteSkipToPrevious(desiredActiveDeviceID: String) async throws {
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .POST,
                url: URL(string: "https://api.spotify.com/v1/me/player/previous?device_id=\(desiredActiveDeviceID)")!
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        // TODO: clean up rest of these
        
        func remoteSeek(toPositionMilliseconds: Int, desiredActiveDeviceID: String) async throws {
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/seek?position_ms=\(toPositionMilliseconds)&device_id=\(desiredActiveDeviceID)")!
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                self.isPlaying = false
                self.showAlertOpenSpotifyOnTargetDevice = true
            } catch {
                throw error
            }
        }
        
        func remoteSetRepeatMode(state: RemotePlaybackState.RepeatState, desiredActiveDeviceID: String, ignoreSpotifyOpenError: Bool = false) async throws {
            do {
            let _ = try await SpotifyRequests.makeRequest(
                type: .PUT,
                url: URL(string: "https://api.spotify.com/v1/me/player/repeat?state=\(state.rawValue)&device_id=\(desiredActiveDeviceID)")!
            )
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                if !ignoreSpotifyOpenError {
                    self.isPlaying = false
                    self.showAlertOpenSpotifyOnTargetDevice = true
                }
            } catch {
                throw error
            }
        }
        
        func remoteSetShuffle(state: Bool, desiredActiveDeviceID: String, ignoreSpotifyOpenError: Bool = false) async throws {
            do {
            // lol
            if state {
                let _ = try await SpotifyRequests.makeRequest(
                    type: .PUT,
                    url: URL(string: "https://api.spotify.com/v1/me/player/shuffle?state=true&device_id=\(desiredActiveDeviceID)")!
                )
            } else {
                let _ = try await SpotifyRequests.makeRequest(
                    type: .PUT,
                    url: URL(string: "https://api.spotify.com/v1/me/player/shuffle?state=false&device_id=\(desiredActiveDeviceID)")!
                )
            }
            } catch SpotifyRequests.Error.response(let httpStatusCode, _) where httpStatusCode == 404 {
                if !ignoreSpotifyOpenError {
                    self.isPlaying = false
                    self.showAlertOpenSpotifyOnTargetDevice = true
                }
            } catch {
                throw error
            }
        }
        
        // unstable with iOS Spotify
//        static func remoteTransferPlaybackTo(deviceID: String) async throws {
//            struct DeviceIDs: Encodable {
//                let device_ids: [String]
//            }
//            let _ = try await SpotifyRequests.makeRequest(
//                type: .PUT,
//                url: URL(string: "https://api.spotify.com/v1/me/player")!,
//                jsonBody: JSONEncoder().encode(DeviceIDs(device_ids: [deviceID]))
//            )
//        }
}
