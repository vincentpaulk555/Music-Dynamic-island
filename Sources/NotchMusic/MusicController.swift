import AppKit
import SwiftUI
import Observation
import os

/// Messages show up in Console.app, or in Terminal with:
/// /usr/bin/log show --last 5m --info --predicate 'subsystem == "com.vincent.NotchMusic"'
let appLog = Logger(subsystem: "com.vincent.NotchMusic", category: "music")

enum PlayerState: Sendable {
    case notRunning, stopped, paused, playing
}

struct Track: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    /// Length in seconds (0 if unknown, e.g. radio streams).
    var duration: Double

    /// Identifies a track well enough to know when to fetch new artwork.
    var key: String { "\(title)|\(artist)|\(album)" }
}

/// Talks to Apple Music and exposes what's playing to the UI.
///
/// Live updates come from Music's "playerInfo" notification (sent on every track/play-state change),
/// so there's no constant polling. AppleScript fills in what the notification lacks (artwork, position)
/// and sends commands. Every script call first checks Music is running, because scripting a
/// closed app would launch it.
@MainActor
@Observable
final class MusicController {
    nonisolated static let bundleID = "com.apple.Music"

    private(set) var state: PlayerState = .notRunning
    private(set) var track: Track?
    private(set) var artwork: NSImage?
    /// A vivid color picked from the artwork, used for the progress bar and waveform.
    private(set) var accentColor: Color = .white
    /// True when macOS blocked us from controlling Music (Automation permission missing).
    private(set) var needsPermission = false
    /// Music's own volume slider, 0–100 (not the Mac's system volume).
    private(set) var volume: Double = 50

    // Playback position at `anchorDate`. The UI calculates the live position from these,
    // so we don't have to ask Music every half second.
    private var positionAnchor: Double = 0
    private var anchorDate = Date()

    // `@ObservationIgnored` = internal bookkeeping that the UI doesn't need to watch.
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private let runner = AppleScriptRunner()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    // Volume changes arrive many times per second while dragging; we send at most one at a time
    // and always finish with the latest value, so Music never falls behind.
    @ObservationIgnored private var volumeSendInFlight = false
    @ObservationIgnored private var queuedVolume: Int?
    @ObservationIgnored private var volumeBeforeMute: Double = 50

    var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    /// True while a song is actively playing (drives the compact notch state).
    var isPlayingTrack: Bool { state == .playing && track != nil }

    /// Current playback position in seconds, estimated for `date`.
    func position(at date: Date) -> Double {
        let elapsed = state == .playing ? date.timeIntervalSince(anchorDate) : 0
        let position = positionAnchor + elapsed
        guard let duration = track?.duration, duration > 0 else { return max(position, 0) }
        return min(max(position, 0), duration)
    }

    // MARK: - Setup

    func start() {
        // Music broadcasts this system-wide whenever the track or play state changes.
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main
        ) { [weak self] note in
            let info = PlayerInfo(note.userInfo)
            MainActor.assumeIsolated { self?.handle(info) }
        })

        // Notice when Music opens or quits.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == MusicController.bundleID else { return }
                let launched = note.name == NSWorkspace.didLaunchApplicationNotification
                MainActor.assumeIsolated { self?.musicDidChangeRunning(launched) }
            })
        }

        refresh()
    }

    // MARK: - Commands

    func togglePlayPause() {
        // Update the UI right away; Music's notification will confirm a moment later.
        let now = Date()
        if state == .playing {
            positionAnchor = position(at: now)
            anchorDate = now
            state = .paused
        } else if state == .paused {
            anchorDate = now
            state = .playing
        }
        send("playpause")
    }

    /// Jumps to `seconds` into the current song.
    func seek(to seconds: Double) {
        guard let track else { return }
        let target = min(max(seconds, 0), track.duration)
        positionAnchor = target  // move the bar immediately; Music catches up a moment later
        anchorDate = Date()
        // %.2f always uses a "." decimal point, which AppleScript expects.
        send(String(format: "set player position to %.2f", target), cache: false)
    }

    func setVolume(_ newValue: Double) {
        volume = min(max(newValue, 0), 100)
        queuedVolume = Int(volume.rounded())
        sendQueuedVolume()
    }

    /// Speaker icon click: mute, or restore the volume from before muting.
    func toggleMute() {
        if volume > 0 {
            volumeBeforeMute = volume
            setVolume(0)
        } else {
            setVolume(volumeBeforeMute > 0 ? volumeBeforeMute : 50)
        }
    }

    func nextTrack() { send("next track") }
    func previousTrack() { send("previous track") }

    /// Only called when the user clicks "Open Music".
    func openMusic() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Re-reads the full player state from Music (track, position, artwork).
    /// Called on launch, on each notification, and each time the panel expands.
    func refresh() {
        guard isMusicRunning else {
            setNotRunning()
            return
        }
        Task {
            do {
                let snapshot = try await runner.run(MusicScripts.status, transform: MusicScripts.parseStatus)
                needsPermission = false
                apply(snapshot)
            } catch {
                handle(error)
            }
        }
    }

    // MARK: - Private

    /// `cache: false` for one-off commands (like seeking to a specific second) that won't be reused.
    private func send(_ command: String, cache: Bool = true) {
        guard isMusicRunning else { return }
        Task {
            do {
                try await runner.run("tell application \"Music\" to \(command)", cache: cache)
            } catch {
                handle(error)
            }
        }
    }

    private func sendQueuedVolume() {
        guard !volumeSendInFlight, let target = queuedVolume, isMusicRunning else { return }
        queuedVolume = nil
        volumeSendInFlight = true
        Task {
            do {
                try await runner.run("tell application \"Music\" to set sound volume to \(target)", cache: false)
            } catch {
                handle(error)
            }
            volumeSendInFlight = false
            sendQueuedVolume()  // send the newest value if the slider moved in the meantime
        }
    }

    private func handle(_ info: PlayerInfo) {
        guard isMusicRunning else { return }
        let now = Date()
        let currentPosition = position(at: now)

        let newState: PlayerState
        switch info.state {
        case "Playing": newState = .playing
        case "Paused": newState = .paused
        default:
            state = .stopped
            track = nil
            clearArtwork()
            return
        }

        // Keep the progress bar sensible until refresh() returns the exact position:
        // a new song starts at 0, otherwise continue from where we are.
        let newTrack = info.title.map {
            Track(title: $0, artist: info.artist ?? "", album: info.album ?? "",
                  duration: info.duration ?? track?.duration ?? 0)
        }
        positionAnchor = (newTrack != nil && newTrack?.key != track?.key) ? 0 : currentPosition
        anchorDate = now
        state = newState
        if let newTrack { track = newTrack }

        refresh()  // the notification doesn't include position or artwork
    }

    private func musicDidChangeRunning(_ launched: Bool) {
        if launched {
            state = .stopped  // Music posts a notification once something starts playing
        } else {
            setNotRunning()
        }
    }

    private func setNotRunning() {
        state = .notRunning
        track = nil
        clearArtwork()
    }

    private func apply(_ snapshot: MusicScripts.Status) {
        state = snapshot.state
        track = snapshot.track
        positionAnchor = snapshot.position
        anchorDate = Date()
        // Don't overwrite the slider while the user is dragging it.
        if let volume = snapshot.volume, !volumeSendInFlight, queuedVolume == nil {
            self.volume = volume
        }

        guard let track = snapshot.track else {
            clearArtwork()
            return
        }
        if track.key != artworkKey {
            // Keep showing the old artwork until the new one arrives, then crossfade.
            artworkKey = track.key
            loadArtwork(for: track)
        }
    }

    /// Asks Music for the artwork first; falls back to Apple's iTunes Search if Music has none
    /// (common for streamed Apple Music songs that aren't in your library).
    private func loadArtwork(for track: Track) {
        let key = track.key
        Task {
            var image = await artworkFromMusic()
            if image == nil, let data = await ITunesArtwork.fetch(for: track) {
                image = NSImage(data: data)
            }
            // Ignore the result if the track changed while we were fetching.
            guard key == artworkKey else { return }
            if image == nil { appLog.info("No artwork found for \(key, privacy: .public)") }

            let accent = image.map { Color(nsColor: ArtworkColors.accent(from: $0)) } ?? .white
            withAnimation(.easeInOut(duration: 0.45)) {
                artwork = image
                accentColor = accent
            }
        }
    }

    private func artworkFromMusic() async -> NSImage? {
        do {
            let data = try await runner.run(MusicScripts.artwork) { $0.data }
            if let image = NSImage(data: data), image.isValid { return image }
            appLog.info("Music gave no usable artwork (\(data.count) bytes)")
        } catch {
            appLog.error("Artwork script failed: \(String(describing: error), privacy: .public)")
        }
        return nil
    }

    private func clearArtwork() {
        artworkKey = nil
        artwork = nil
        accentColor = .white
    }

    private func handle(_ error: Error) {
        if let error = error as? AppleScriptError, error.isNotAuthorized {
            needsPermission = true
        } else {
            appLog.error("AppleScript failed: \(String(describing: error), privacy: .public)")
        }
    }
}

/// The useful fields from Music's "playerInfo" notification.
private struct PlayerInfo: Sendable {
    let state: String?
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?

    init(_ userInfo: [AnyHashable: Any]?) {
        state = userInfo?["Player State"] as? String
        title = userInfo?["Name"] as? String
        artist = userInfo?["Artist"] as? String
        album = userInfo?["Album"] as? String
        // "Total Time" is in milliseconds.
        duration = (userInfo?["Total Time"] as? NSNumber).map { $0.doubleValue / 1000 }
    }
}

/// AppleScript sources and parsing. Kept outside MusicController so parsing can run on the background queue.
/// Careful with variable names in AppleScript: short words like `st` are reserved ("1st") and break compiling.
private enum MusicScripts {
    struct Status: Sendable {
        var state: PlayerState
        var track: Track?
        var position: Double
        var volume: Double?
    }

    static let status = """
    tell application "Music"
        if player state is stopped then return {"stopped"}
        if player state is paused then
            set playerStatus to "paused"
        else
            set playerStatus to "playing"
        end if
        try
            set t to current track
            return {playerStatus, name of t, artist of t, album of t, duration of t, player position, sound volume}
        on error
            return {playerStatus}
        end try
    end tell
    """

    static let artwork = """
    tell application "Music"
        try
            return raw data of artwork 1 of current track
        on error
            try
                return data of artwork 1 of current track
            end try
        end try
    end tell
    return ""
    """

    /// AppleScript lists are 1-indexed.
    @Sendable static func parseStatus(_ result: NSAppleEventDescriptor) -> Status {
        let stateString = result.atIndex(1)?.stringValue ?? "stopped"
        let state: PlayerState = switch stateString {
        case "playing": .playing
        case "paused": .paused
        default: .stopped
        }
        guard state != .stopped, result.numberOfItems >= 6 else {
            return Status(state: state, track: nil, position: 0, volume: nil)
        }
        let track = Track(
            title: result.atIndex(2)?.stringValue ?? "",
            artist: result.atIndex(3)?.stringValue ?? "",
            album: result.atIndex(4)?.stringValue ?? "",
            duration: result.atIndex(5)?.doubleValue ?? 0
        )
        return Status(state: state, track: track,
                      position: result.atIndex(6)?.doubleValue ?? 0,
                      volume: result.numberOfItems >= 7 ? result.atIndex(7)?.doubleValue : nil)
    }
}
