import AppKit
import CoreGraphics
import Foundation
import os
import PersonaCore

/// Coordinates automatic window tiling, user drag snap-back, and frame restoration.
@MainActor
public final class TilingController {
    public static let shared = TilingController()

    private let logger = Logger(subsystem: "dev.persona.mode", category: "Tiling")

    public var provider: AXWindowProvider
    public var config: AppConfig
    public var journal: FrameJournal
    public var userFloatOverrides: Set<CGWindowID> = []
    public var isAXTrusted: () -> Bool
    public var screenProvider: @MainActor () -> [ScreenModel]

    public private(set) var isEnabled: Bool = true
    private var eventSub: EventBus.SubscriptionToken?
    private var debounceTimer: DispatchSourceTimer?
    private var dragSettleTimer: DispatchSourceTimer?
    private var selfMoveTokens: [CGWindowID: Date] = [:]

    public init(
        provider: AXWindowProvider = SystemAXWindowProvider(),
        config: AppConfig = AppConfig(),
        journal: FrameJournal = FrameJournal(),
        isAXTrusted: @escaping () -> Bool = { AXPermission.shared.isTrusted },
        screenProvider: @escaping @MainActor () -> [ScreenModel] = { ScreenModel.current() }
    ) {
        self.provider = provider
        self.config = config
        self.journal = journal
        self.isAXTrusted = isAXTrusted
        self.screenProvider = screenProvider
        self.isEnabled = config.tiling.enabled
    }

    public func start() {
        guard eventSub == nil else { return }

        eventSub = EventBus.shared.subscribe { [weak self] event in
            self?.handleEvent(event)
        }

        if isEnabled && isAXTrusted() {
            scheduleRetileAll(delayMs: 100)
        } else if isEnabled && !isAXTrusted() {
            logger.warning("Accessibility permission is not granted; automatic window tiling is waiting for trust.")
        }
    }

    public func stop() {
        if let sub = eventSub {
            EventBus.shared.unsubscribe(sub)
            eventSub = nil
        }
        debounceTimer?.cancel()
        debounceTimer = nil
        dragSettleTimer?.cancel()
        dragSettleTimer = nil
    }

    public func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        self.isEnabled = newConfig.tiling.enabled
        AppState.shared.tilingEnabled = newConfig.tiling.enabled
        if let sys = provider as? SystemAXWindowProvider {
            sys.configFloatApps = newConfig.tiling.floatApps
        }
        if isEnabled && isAXTrusted() {
            scheduleRetileAll(delayMs: 60)
        }
    }

    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        AppState.shared.tilingEnabled = enabled
        if enabled {
            scheduleRetileAll(delayMs: 60)
        }
    }

    public func toggleFloatFocused() {
        guard let focused = provider.getFocusedWindow() else { return }
        if userFloatOverrides.contains(focused.id) {
            userFloatOverrides.remove(focused.id)
            if let sys = provider as? SystemAXWindowProvider {
                sys.userFloatOverrides.remove(focused.id)
            }
        } else {
            userFloatOverrides.insert(focused.id)
            if let sys = provider as? SystemAXWindowProvider {
                sys.userFloatOverrides.insert(focused.id)
            }
        }
        scheduleRetileAll(delayMs: 30)
    }

    public func retileAll() {
        guard isEnabled else { return }
        for model in screenProvider() {
            retile(screen: model)
        }
    }

    public func retile(screen: ScreenModel) {
        guard isEnabled else { return }

        // Graceful Accessibility fallback: log warning and no-op rather than crashing
        guard isAXTrusted() else {
            logger.warning("Accessibility permission is not granted; window tiling is inactive.")
            return
        }

        // Convert AppKit screen frame (bottom-left) to Quartz AX coordinates (top-left)
        let screens = screenProvider()
        let primaryH = screens.first?.frame.height ?? screen.frame.height
        let screenAX = CoordinateSpace.toAX(screen.frame, primaryHeight: primaryH)

        let allWindows = provider.getWindows(on: screenAX)
        let tilableWindows = allWindows.filter {
            FloatRules.isEligibleForTiling(
                $0,
                userFloatOverrides: userFloatOverrides,
                configFloatApps: config.tiling.floatApps
            )
        }
        guard !tilableWindows.isEmpty else { return }

        // Record pre-tile frames before first layout (skip if live window moves are gated)
        let movesBlocked = (provider is SystemAXWindowProvider) && SystemAXWindowProvider.areWindowMovesBlocked()
        if !movesBlocked {
            for win in tilableWindows {
                journal.recordIfNeeded(window: win)
            }
        }

        let ids = tilableWindows.map { $0.id }
        // Guardrail 2: Reserve at least the 38pt Top Bar inset (plus configured outer and inner gaps)
        let bar = BarInset(
            marginTop: config.topBar.marginTop,
            height: max(38, max(config.topBar.height, screen.safeTop))
        )
        let gaps = Gaps(
            outer: config.tiling.gaps.outer,
            inner: config.tiling.gaps.inner
        )

        let layout = LayoutEngine.layout(
            ids: ids,
            screen: screenAX,
            bar: bar,
            gaps: gaps,
            algorithm: config.tiling.algorithm,
            splitRatio: config.tiling.splitRatio
        )

        let now = Date()
        for win in tilableWindows {
            guard let targetFrame = layout[win.id] else { continue }
            // Tag self-move token to ignore echo moved/resized events within 250ms
            selfMoveTokens[win.id] = now
            _ = provider.setWindowFrame(window: win, frame: targetFrame)
        }
    }

    public func restoreFrames() {
        journal.restoreFrames(provider: provider)
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: PersonaEvent) {
        switch event {
        case .windowCreated, .windowDestroyed, .tileRequested:
            scheduleRetileAll(delayMs: 60)

        case .spaceChanged, .screensChanged:
            scheduleRetileAll(delayMs: 120)

        case .axTrustChanged(let trusted):
            if trusted && isEnabled {
                scheduleRetileAll(delayMs: 150)
            }

        case .frameChangedExternally(let wid, _):
            // Check if this was a self-move echo
            if let token = selfMoveTokens[wid], Date().timeIntervalSince(token) < 0.25 {
                return
            }

            // External user drag/resize: if snap-back is enabled, settle and snap back
            if config.tiling.snapBackOnDrag {
                dragSettleTimer?.cancel()
                let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
                timer.schedule(deadline: .now() + .milliseconds(150))
                timer.setEventHandler { [weak self] in
                    self?.retileAll()
                }
                timer.resume()
                self.dragSettleTimer = timer
            }

        default:
            break
        }
    }

    private func scheduleRetileAll(delayMs: Int) {
        debounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(delayMs))
        timer.setEventHandler { [weak self] in
            self?.retileAll()
        }
        timer.resume()
        self.debounceTimer = timer
    }
}
