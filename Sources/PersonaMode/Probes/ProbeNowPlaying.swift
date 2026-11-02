import Foundation
import PersonaCore
import PersonaKit

public enum ProbeNowPlaying: Probe {
    public static func run(args: [String]) -> Int32 {
        let service = NowPlayingService.shared
        service.start()

        let seconds = ProbeIO.double(of: "--seconds", in: args, default: 1.5)
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))

        if let np = AppState.shared.nowPlaying {
            let result: [String: Any] = [
                "source": np.source,
                "state": np.state.rawValue,
                "title": np.title,
                "artist": np.artist,
                "album": np.album
            ]
            service.stop()
            return ProbeIO.emit(result, args: args)
        } else {
            service.stop()
            return ProbeIO.emit(["state": "none"], args: args)
        }
    }
}

public enum ProbeNowPlayingInject: Probe {
    public static func run(args: [String]) -> Int32 {
        let service = NowPlayingService.shared
        service.start()

        // Inject simulated Spotify track info via DistributedNotificationCenter
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            userInfo: [
                "Player State": "Playing",
                "Name": "Burn My Dread",
                "Artist": "Lotus Juice",
                "Album": "Persona 3 Reload OST"
            ],
            deliverImmediately: true
        )

        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        service.stop()

        if let np = AppState.shared.nowPlaying {
            let result: [String: Any] = [
                "source": np.source,
                "state": np.state.rawValue,
                "title": np.title,
                "artist": np.artist,
                "album": np.album
            ]
            return ProbeIO.emit(result, args: args)
        } else {
            return ProbeIO.emit(["error": "Injection did not update state"], args: args)
        }
    }
}
