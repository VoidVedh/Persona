import AppKit
import CoreGraphics
import Foundation
import PersonaCore

/// Coordinates active-window border overlays across displays, following focus and window movements.
@MainActor
public final class BorderController {
    public static let shared = BorderController()

    public var provider: AXWindowProvider
    public var config: AppConfig
    public var screenProvider: @MainActor () -> [ScreenModel]
    public private(set) var borderWindows: [CGDirectDisplayID: BorderOverlayWindow] = [:]
    private var eventSub: EventBus.SubscriptionToken?
    private var coalesceTimer: DispatchSourceTimer?
    private var pendingFrameUpdate: (wid: CGWindowID, frame: CGRect)?
    public private(set) var isRunning = false
    private var orderFront = true

    public private(set) var currentFocusedID: CGWindowID?
    public private(set) var currentBorderFrameAppKit: CGRect?
    public private(set) var isBorderVisible: Bool = false

    public init(
        provider: AXWindowProvider = SystemAXWindowProvider(),
        config: AppConfig = AppConfig(),
        screenProvider: @escaping @MainActor () -> [ScreenModel] = { ScreenModel.current() }
    ) {
        self.provider = provider
        self.config = config
        self.screenProvider = screenProvider
    }

    public func start(orderFront: Bool = true) {
        guard !isRunning else { return }
        isRunning = true
        self.orderFront = orderFront

        rebuildWindows()

        eventSub = EventBus.shared.subscribe { [weak self] event in
            self?.handleEvent(event)
        }

        updateFocus()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        coalesceTimer?.cancel()
        coalesceTimer = nil
        pendingFrameUpdate = nil

        if let sub = eventSub {
            EventBus.shared.unsubscribe(sub)
            eventSub = nil
        }

        for win in borderWindows.values {
            win.updateRing(rectAppKit: nil, animated: false)
            win.orderOut(nil)
            win.close()
        }
        borderWindows.removeAll()
        isBorderVisible = false
        currentBorderFrameAppKit = nil
        currentFocusedID = nil
    }

    public func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        guard isRunning else { return }
        updateFocus()
    }

    public func rebuildWindows() {
        for win in borderWindows.values {
            win.updateRing(rectAppKit: nil, animated: false)
            win.orderOut(nil)
            win.close()
        }
        borderWindows.removeAll()

        for model in screenProvider() {
            let borderWin = BorderOverlayWindow(screen: model)
            if orderFront {
                borderWin.orderFrontRegardless()
            }
            borderWindows[model.id] = borderWin
        }
    }

    public func updateFocus() {
        guard isRunning else { return }
        guard config.border.enabled else {
            clearBorder()
            return
        }

        guard let win = provider.getFocusedWindow() else {
            clearBorder()
            return
        }

        // Enforce self-exclusion, layer 0, non-minimized/hidden/fullscreen, and min size
        guard FloatRules.isEligibleForBorder(win) else {
            clearBorder()
            return
        }

        // For live WindowServer windows, verify kCGWindowLayer == 0
        if provider is SystemAXWindowProvider,
           let infoList = CGWindowListCopyWindowInfo([.optionIncludingWindow], win.id) as? [[String: Any]],
           let info = infoList.first,
           let layer = info[kCGWindowLayer as String] as? Int,
           layer != 0 {
            clearBorder()
            return
        }

        currentFocusedID = win.id
        drawBorder(for: win.frame)
    }

    private func drawBorder(for winFrameAX: CGRect, animated: Bool = true) {
        let screens = screenProvider()
        guard let primaryScreen = screens.first else {
            clearBorder()
            return
        }
        let primaryH = primaryScreen.frame.height

        let borderWidth = BorderGeometry.clampedWidth(
            width: config.border.width,
            innerGap: config.tiling.gaps.inner
        )
        let ringAppKit = BorderGeometry.ringRectAppKit(
            windowFrameAX: winFrameAX,
            borderWidth: borderWidth,
            primaryScreenHeight: primaryH
        )

        currentBorderFrameAppKit = ringAppKit
        isBorderVisible = true

        let center = CGPoint(x: ringAppKit.midX, y: ringAppKit.midY)
        for (_, win) in borderWindows {
            if win.screenModel.frame.contains(center) {
                win.updateRing(
                    rectAppKit: ringAppKit,
                    cornerRadius: config.border.cornerRadius,
                    borderWidth: borderWidth,
                    pulse: config.border.pulse,
                    animated: animated
                )
            } else {
                win.updateRing(rectAppKit: nil, animated: false)
            }
        }
    }

    public func clearBorder() {
        isBorderVisible = false
        currentBorderFrameAppKit = nil
        currentFocusedID = nil
        for win in borderWindows.values {
            win.updateRing(rectAppKit: nil, animated: false)
        }
    }

    private func handleEvent(_ event: PersonaEvent) {
        switch event {
        case .focusChanged(_, let wid):
            currentFocusedID = wid
            updateFocus()

        case .frameChangedExternally(let wid, let frame):
            if wid == currentFocusedID {
                coalesceFrameUpdate(wid: wid, frame: frame)
            }

        case .windowDestroyed(let wid):
            if wid == currentFocusedID {
                clearBorder()
            }

        case .spaceChanged:
            updateFocus()

        case .screensChanged:
            rebuildWindows()
            updateFocus()

        case .axTrustChanged:
            updateFocus()

        default:
            break
        }
    }

    private func coalesceFrameUpdate(wid: CGWindowID, frame: CGRect) {
        pendingFrameUpdate = (wid, frame)
        guard coalesceTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(16))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.coalesceTimer?.cancel()
            self.coalesceTimer = nil
            if let pending = self.pendingFrameUpdate, pending.wid == self.currentFocusedID {
                self.pendingFrameUpdate = nil
                self.drawBorder(for: pending.frame, animated: false)
            }
        }
        timer.resume()
        coalesceTimer = timer
    }
}
