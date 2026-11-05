import AppKit
import Combine
import Foundation
import PersonaCore

/// Publishes coalesced state patches from `AppState` to active `topbar` and `hud` WebKit surfaces.
@MainActor
public final class WebStatePublisher {
    public static let shared = WebStatePublisher()

    private struct WeakSurface {
        weak var view: WebSurfaceView?
        let screen: ScreenModel
    }

    private var topBarSurfaces: [WeakSurface] = []
    private var hudSurfaces: [WeakSurface] = []
    private var cancellable: AnyCancellable?
    private var minuteTimer: DispatchSourceTimer?
    private var coalesceScheduled = false
    private var config: AppConfig = AppConfig()

    public init() {}

    public func start(config: AppConfig = AppConfig()) {
        self.config = config
        guard cancellable == nil else { return }

        cancellable = AppState.shared.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.schedulePublish()
            }
        }

        let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
        timer.schedule(deadline: .now() + .seconds(30), repeating: .seconds(30))
        timer.setEventHandler { [weak self] in
            AppState.shared.updateDarkHourPhase()
            self?.schedulePublish()
        }
        timer.resume()
        self.minuteTimer = timer
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
        minuteTimer?.cancel()
        minuteTimer = nil
        for item in topBarSurfaces {
            item.view?.teardown()
        }
        for item in hudSurfaces {
            item.view?.teardown()
        }
        topBarSurfaces.removeAll()
        hudSurfaces.removeAll()
        WebCacheCleaner.cleanup()
    }

    public func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        schedulePublish()
    }

    public func registerTopBar(_ view: WebSurfaceView, screen: ScreenModel) {
        topBarSurfaces.removeAll { $0.view == nil || $0.view === view }
        topBarSurfaces.append(WeakSurface(view: view, screen: screen))
        let state = makeBarState(for: screen)
        view.bridge.publish(WebStateJSON.encodeDictionary(state))
    }

    public func registerHUD(_ view: WebSurfaceView, screen: ScreenModel) {
        hudSurfaces.removeAll { $0.view == nil || $0.view === view }
        hudSurfaces.append(WeakSurface(view: view, screen: screen))
        let state = makeHudState(for: screen)
        view.bridge.publish(WebStateJSON.encodeDictionary(state))
    }

    public func schedulePublish() {
        guard !coalesceScheduled else { return }
        coalesceScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.coalesceScheduled = false
            self.publishNow()
        }
    }

    public func publishNow() {
        topBarSurfaces.removeAll { $0.view == nil }
        hudSurfaces.removeAll { $0.view == nil }

        for entry in topBarSurfaces {
            guard let view = entry.view else { continue }
            let state = makeBarState(for: entry.screen)
            view.bridge.publish(WebStateJSON.encodeDictionary(state))
        }

        for entry in hudSurfaces {
            guard let view = entry.view else { continue }
            let state = makeHudState(for: entry.screen)
            view.bridge.publish(WebStateJSON.encodeDictionary(state))
        }
    }

    public func makeBarState(for screen: ScreenModel, date: Date = Date()) -> BarState {
        let appState = AppState.shared
        let slot = TimeOfDaySlot.slot(for: date, calendar: .current, force: appState.forcedDarkHour)
        let phaseStr = (slot == .darkHour || appState.darkHourPhase == .darkHour) ? "darkHour" : "daytime"

        let notchGeo: WebNotchGeometry
        let barFrame = TopBarPanel.frame(for: screen, config: config.topBar)
        if let split = WindowGeometry.clusterSplit(barFrame: barFrame, auxLeft: screen.auxLeft, auxRight: screen.auxRight) {
            notchGeo = WebNotchGeometry(x: Double(split.leftWidth), w: Double(split.gap))
        } else {
            notchGeo = WebNotchGeometry(x: 0, w: 0)
        }

        var spaces: [WebSpaceItem] = []
        let activeIdx = max(1, appState.spaceSnapshot.activeIndex)
        let knownCount = max(5, appState.spaceSnapshot.count)
        for idx in 1...min(5, knownCount) {
            spaces.append(WebSpaceItem(index: idx, active: idx == activeIdx, occupied: true))
        }

        let tel = appState.telemetry
        let webTel = WebTelemetryState(
            cpu: Int(tel.cpu.rounded()),
            mem: Int(tel.ram.rounded()),
            battery: tel.battery.hasBattery ? Int(tel.battery.percent.rounded()) : nil,
            charging: tel.battery.isCharging,
            wifiBars: tel.wifi.isConnected ? tel.wifi.bars : 0,
            volume: tel.volume.percent,
            muted: tel.volume.isMuted
        )

        let npState: WebNowPlayingState
        if let np = appState.nowPlaying {
            npState = WebNowPlayingState(
                state: np.state == .playing ? "playing" : "paused",
                title: np.title.isEmpty ? "UNKNOWN TRACK" : np.title.uppercased(),
                artist: np.artist.isEmpty ? "UNKNOWN ARTIST" : np.artist.uppercased(),
                source: np.source
            )
        } else {
            npState = WebNowPlayingState(state: "none", title: "NOTHING PLAYING", artist: "S.E.E.S. AUDIO UNIT", source: "")
        }

        let dfTime = DateFormatter()
        dfTime.locale = Locale(identifier: "en_US_POSIX")
        dfTime.dateFormat = "HH:mm"

        let dfDay = DateFormatter()
        dfDay.locale = Locale(identifier: "en_US_POSIX")
        dfDay.dateFormat = "EEE dd"

        return BarState(
            screen: WebScreenGeometry(
                width: Double(screen.frame.width),
                height: Double(max(config.topBar.height, screen.safeTop)),
                notch: notchGeo
            ),
            spaces: spaces,
            focusedApp: appState.focusedApp.isEmpty ? "DESKTOP" : appState.focusedApp.uppercased(),
            focusedTitle: appState.focusedTitle,
            slot: slot.label,
            phase: phaseStr,
            telemetry: webTel,
            nowPlaying: npState,
            clockTime: dfTime.string(from: date),
            clockDay: dfDay.string(from: date).uppercased(),
            runMode: appState.runMode.rawValue,
            calm: appState.ambientPaused || !config.hud.ambientAnimation
        )
    }

    public func makeHudState(for screen: ScreenModel, date: Date = Date()) -> HudState {
        let appState = AppState.shared
        let slot = TimeOfDaySlot.slot(for: date, calendar: .current, force: appState.forcedDarkHour)
        let phaseStr = (slot == .darkHour || appState.darkHourPhase == .darkHour) ? "darkHour" : "daytime"
        let moon = MoonPhase.compute(for: date)

        let dfMonth = DateFormatter()
        dfMonth.locale = Locale(identifier: "en_US_POSIX")
        dfMonth.dateFormat = "MM"

        let dfDay = DateFormatter()
        dfDay.locale = Locale(identifier: "en_US_POSIX")
        dfDay.dateFormat = "dd"

        let dfDow = DateFormatter()
        dfDow.locale = Locale(identifier: "en_US_POSIX")
        dfDow.dateFormat = "EEE"

        let npState: WebNowPlayingState
        if let np = appState.nowPlaying {
            npState = WebNowPlayingState(
                state: np.state == .playing ? "playing" : "paused",
                title: np.title.isEmpty ? "UNKNOWN TRACK" : np.title.uppercased(),
                artist: np.artist.isEmpty ? "UNKNOWN ARTIST" : np.artist.uppercased(),
                source: np.source
            )
        } else {
            npState = WebNowPlayingState(state: "none", title: "NOTHING PLAYING", artist: "S.E.E.S. AUDIO UNIT", source: "")
        }

        return HudState(
            screen: WebScreenGeometry(width: Double(screen.frame.width), height: Double(screen.frame.height)),
            month: dfMonth.string(from: date),
            day: dfDay.string(from: date),
            dow: dfDow.string(from: date).uppercased(),
            slot: slot.label,
            slotAccent: slot.accentToken,
            phase: phaseStr,
            moon: WebMoonState.from(moon),
            nowPlaying: npState,
            wallpaperMode: config.wallpaper.mode.rawValue,
            calm: appState.ambientPaused || !config.hud.ambientAnimation,
            fps: config.hud.fps,
            particles: config.hud.particles
        )
    }
}
