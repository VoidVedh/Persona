import Foundation

public enum PlaybackState: String, Codable, Equatable {
    case playing
    case paused
    case stopped
}

public struct NowPlaying: Codable, Equatable {
    public var source: String
    public var state: PlaybackState
    public var title: String
    public var artist: String
    public var album: String

    public init(source: String, state: PlaybackState, title: String, artist: String, album: String = "") {
        self.source = source
        self.state = state
        self.title = title
        self.artist = artist
        self.album = album
    }
}

/// Parses the distributed notifications Music.app and Spotify broadcast (ADR-7). No MediaRemote.
public enum NowPlayingParser {
    public static let musicNotification = "com.apple.Music.playerInfo"
    public static let legacyMusicNotification = "com.apple.iTunes.playerInfo"
    public static let spotifyNotification = "com.spotify.client.PlaybackStateChanged"

    public static let notificationNames = [musicNotification, legacyMusicNotification, spotifyNotification]

    /// Human-readable source for a notification name (nil if not a known player).
    public static func source(forNotification name: String) -> String? {
        switch name {
        case musicNotification, legacyMusicNotification: return "music"
        case spotifyNotification: return "spotify"
        default: return nil
        }
    }

    public static func state(from raw: String?) -> PlaybackState {
        switch raw?.lowercased() {
        case "playing": return .playing
        case "paused": return .paused
        default: return .stopped
        }
    }

    /// Returns nil for unknown notifications; a `.stopped` value for Stopped (callers treat it as idle).
    public static func parse(notification name: String, userInfo: [AnyHashable: Any]?) -> NowPlaying? {
        guard let source = source(forNotification: name), let info = userInfo else { return nil }
        let stateRaw = info["Player State"] as? String
        return NowPlaying(
            source: source,
            state: state(from: stateRaw),
            title: (info["Name"] as? String) ?? "",
            artist: (info["Artist"] as? String) ?? "",
            album: (info["Album"] as? String) ?? ""
        )
    }

    /// Parses the tab-separated seed script output `name \t artist \t state`.
    public static func parseSeed(source: String, output: String) -> NowPlaying? {
        let trimmed = output.trimmingCharacters(in: .newlines)
        let parts = trimmed.components(separatedBy: "\t")
        guard parts.count >= 3, !parts[0].isEmpty else { return nil }
        return NowPlaying(source: source, state: state(from: parts[2]), title: parts[0], artist: parts[1])
    }

    /// AppleScript used to seed the initial state — only ever run for an already-running player.
    public static func seedScript(bundleID: String) -> String {
        """
        tell application id "\(bundleID)" to get (name of current track) & tab & (artist of current track) & tab & (player state as string)
        """
    }
}
