import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import PersonaCore

/// Model representing a tracked application window in Quartz AX (top-left) coordinates.
public struct ManagedWindow: Identifiable, Equatable {
    public let id: CGWindowID
    public let pid: pid_t
    public let bundleId: String
    public var title: String
    public var frame: CGRect
    public var layer: Int
    public var role: String
    public var subrole: String
    public var isMinimized: Bool
    public var isHidden: Bool
    public var isFullscreen: Bool
    public var isResizable: Bool
    public var isTilable: Bool
    public var element: AXUIElement?

    public init(
        id: CGWindowID,
        pid: pid_t,
        bundleId: String,
        title: String = "",
        frame: CGRect,
        layer: Int = 0,
        role: String = "AXWindow",
        subrole: String = "AXStandardWindow",
        isMinimized: Bool = false,
        isHidden: Bool = false,
        isFullscreen: Bool = false,
        isResizable: Bool = true,
        isTilable: Bool = true,
        element: AXUIElement? = nil
    ) {
        self.id = id
        self.pid = pid
        self.bundleId = bundleId
        self.title = title
        self.frame = frame
        self.layer = layer
        self.role = role
        self.subrole = subrole
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.isFullscreen = isFullscreen
        self.isResizable = isResizable
        self.isTilable = isTilable
        self.element = element
    }

    public static func == (lhs: ManagedWindow, rhs: ManagedWindow) -> Bool {
        lhs.id == rhs.id &&
        lhs.pid == rhs.pid &&
        lhs.bundleId == rhs.bundleId &&
        lhs.frame == rhs.frame &&
        lhs.layer == rhs.layer &&
        lhs.role == rhs.role &&
        lhs.subrole == rhs.subrole &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.isHidden == rhs.isHidden &&
        lhs.isFullscreen == rhs.isFullscreen &&
        lhs.isResizable == rhs.isResizable &&
        lhs.isTilable == rhs.isTilable &&
        lhs.title == rhs.title
    }
}

/// Abstract interface for querying and manipulating application windows.
public protocol AXWindowProvider: AnyObject {
    func getWindows(on screen: CGRect) -> [ManagedWindow]
    func getFocusedWindow() -> ManagedWindow?
    func setWindowFrame(window: ManagedWindow, frame: CGRect) -> Bool
}

/// Focus title provider backed by `AXWindowProvider`.
public final class AXFocusTitleProvider: FocusTitleProvider {
    private let provider: AXWindowProvider

    public init(provider: AXWindowProvider = SystemAXWindowProvider()) {
        self.provider = provider
    }

    public func title(for pid: pid_t) -> String? {
        guard let win = provider.getFocusedWindow(), win.pid == pid else {
            return nil
        }
        return win.title.isEmpty ? nil : win.title
    }
}

/// Concrete window provider using the live macOS Accessibility and CoreGraphics APIs.
public final class SystemAXWindowProvider: AXWindowProvider {
    public var userFloatOverrides: Set<CGWindowID> = []
    public var configFloatApps: [String] = []
    public var environmentProvider: () -> [String: String]

    public init(
        configFloatApps: [String] = [],
        environmentProvider: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment }
    ) {
        self.configFloatApps = configFloatApps
        self.environmentProvider = environmentProvider
    }

    public static func areWindowMovesBlocked(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        return (env["PERSONA_DRY_RUN"] == "1" || env["PERSONA_NO_WINDOW_MOVES"] == "1") &&
            env["PERSONA_TILING_LIVE"] != "1"
    }

    public func getWindows(on screen: CGRect) -> [ManagedWindow] {
        guard AXPermission.shared.isTrusted else {
            return getWindowsViaWindowServer(on: screen)
        }

        // Map CGWindowID -> kCGWindowLayer and active PIDs from WindowServer
        let (windowLayers, onScreenPIDs) = currentWindowLayersAndPIDs()
        var results: [ManagedWindow] = []
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.processIdentifier != ownPID,
                  onScreenPIDs.contains(app.processIdentifier),
                  app.bundleIdentifier != "dev.persona.mode",
                  !app.isHidden else {
                continue
            }
            let pid = app.processIdentifier
            let bundleId = app.bundleIdentifier ?? ""

            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windowsList = windowsRef as? [AXUIElement] else {
                continue
            }

            for winElement in windowsList {
                guard let wid = AXPrivate.windowID(for: winElement) else { continue }
                guard let layer = windowLayers[wid], layer == 0 else { continue }

                guard let pos = AXPrivate.copyPointAttribute(element: winElement, attribute: kAXPositionAttribute),
                      let size = AXPrivate.copySizeAttribute(element: winElement, attribute: kAXSizeAttribute) else {
                    continue
                }
                let frameAX = CGRect(origin: pos, size: size)

                // Window center must lie on this screen (both in AX coordinates)
                let center = CGPoint(x: frameAX.midX, y: frameAX.midY)
                guard screen.contains(center) else { continue }

                let role = AXPrivate.copyStringAttribute(element: winElement, attribute: kAXRoleAttribute as String) ?? "AXWindow"
                let subrole = AXPrivate.copyStringAttribute(element: winElement, attribute: kAXSubroleAttribute as String) ?? "AXStandardWindow"
                let title = AXPrivate.copyStringAttribute(element: winElement, attribute: kAXTitleAttribute as String) ?? ""

                var minRef: CFTypeRef?
                let isMinimized = (AXUIElementCopyAttributeValue(winElement, kAXMinimizedAttribute as CFString, &minRef) == .success) && ((minRef as? Bool) ?? false)

                var fsRef: CFTypeRef?
                let isFullscreen = (AXUIElementCopyAttributeValue(winElement, "AXFullScreen" as CFString, &fsRef) == .success) && ((fsRef as? Bool) ?? false)

                var settableSize: DarwinBoolean = false
                var settablePos: DarwinBoolean = false
                _ = AXUIElementIsAttributeSettable(winElement, kAXSizeAttribute as CFString, &settableSize)
                _ = AXUIElementIsAttributeSettable(winElement, kAXPositionAttribute as CFString, &settablePos)
                let isResizable = settableSize.boolValue && settablePos.boolValue

                let tilable = FloatRules.isTilable(
                    windowID: wid,
                    pid: pid,
                    ownPID: ownPID,
                    bundleId: bundleId,
                    layer: layer,
                    role: role,
                    subrole: subrole,
                    isMinimized: isMinimized,
                    isHidden: app.isHidden,
                    isFullscreen: isFullscreen,
                    size: size,
                    isResizable: isResizable,
                    userFloatOverrides: userFloatOverrides,
                    configFloatApps: configFloatApps
                )

                let win = ManagedWindow(
                    id: wid,
                    pid: pid,
                    bundleId: bundleId,
                    title: title,
                    frame: frameAX,
                    layer: layer,
                    role: role,
                    subrole: subrole,
                    isMinimized: isMinimized,
                    isHidden: app.isHidden,
                    isFullscreen: isFullscreen,
                    isResizable: isResizable,
                    isTilable: tilable,
                    element: winElement
                )
                results.append(win)
            }
        }

        return results
    }

    public func getFocusedWindow() -> ManagedWindow? {
        guard AXPermission.shared.isTrusted else {
            return getFocusedWindowViaWindowServer()
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef) == .success,
              let focusedApp = focusedAppRef else {
            return getFocusedWindowViaWindowServer()
        }

        let appElement = focusedApp as! AXUIElement
        var pid: pid_t = 0
        _ = AXUIElementGetPid(appElement, &pid)
        guard pid != ownPID else { return nil }

        let runningApp = NSRunningApplication(processIdentifier: pid)
        let bundleId = runningApp?.bundleIdentifier ?? ""
        guard bundleId != "dev.persona.mode", runningApp?.isHidden != true else {
            return nil
        }

        var focusedWinRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
              let focusedWin = focusedWinRef else {
            return getFocusedWindowViaWindowServer()
        }

        let winElement = focusedWin as! AXUIElement
        guard let wid = AXPrivate.windowID(for: winElement),
              let pos = AXPrivate.copyPointAttribute(element: winElement, attribute: kAXPositionAttribute),
              let size = AXPrivate.copySizeAttribute(element: winElement, attribute: kAXSizeAttribute) else {
            return getFocusedWindowViaWindowServer()
        }

        let title = AXPrivate.copyStringAttribute(element: winElement, attribute: kAXTitleAttribute as String) ?? ""
        let role = AXPrivate.copyStringAttribute(element: winElement, attribute: kAXRoleAttribute as String) ?? "AXWindow"
        let subrole = AXPrivate.copyStringAttribute(element: winElement, attribute: kAXSubroleAttribute as String) ?? "AXStandardWindow"

        var minRef: CFTypeRef?
        let isMinimized = (AXUIElementCopyAttributeValue(winElement, kAXMinimizedAttribute as CFString, &minRef) == .success) && ((minRef as? Bool) ?? false)

        var fsRef: CFTypeRef?
        let isFullscreen = (AXUIElementCopyAttributeValue(winElement, "AXFullScreen" as CFString, &fsRef) == .success) && ((fsRef as? Bool) ?? false)

        let layer = windowLayer(for: wid) ?? 0

        let candidate = ManagedWindow(
            id: wid,
            pid: pid,
            bundleId: bundleId,
            title: title,
            frame: CGRect(origin: pos, size: size),
            layer: layer,
            role: role,
            subrole: subrole,
            isMinimized: isMinimized,
            isHidden: runningApp?.isHidden ?? false,
            isFullscreen: isFullscreen,
            element: winElement
        )

        guard FloatRules.isEligibleForBorder(candidate, ownPID: ownPID) else {
            return nil
        }
        return candidate
    }

    public func setWindowFrame(window: ManagedWindow, frame: CGRect) -> Bool {
        if Self.areWindowMovesBlocked(env: environmentProvider()) {
            return true
        }

        guard AXPermission.shared.isTrusted else { return false }

        let targetElement: AXUIElement?
        if let el = window.element {
            targetElement = el
        } else {
            targetElement = resolveAXElement(pid: window.pid, windowID: window.id)
        }
        guard let element = targetElement else { return false }

        // Size -> Position -> Size protocol to satisfy apps with aspect ratio / min size clamps
        var targetSize = frame.size
        var targetPos = frame.origin

        guard let sizeVal = AXValueCreate(.cgSize, &targetSize),
              let posVal = AXValueCreate(.cgPoint, &targetPos) else {
            return false
        }

        let s1 = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeVal)
        let s2 = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posVal)
        let s3 = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeVal)

        return s1 == .success || s2 == .success || s3 == .success
    }

    private func resolveAXElement(pid: pid_t, windowID: CGWindowID) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windowsList = windowsRef as? [AXUIElement] else {
            return nil
        }
        for winElement in windowsList {
            if AXPrivate.windowID(for: winElement) == windowID {
                return winElement
            }
        }
        return nil
    }

    public static func onScreenLayerZeroPIDs() -> Set<pid_t> {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }
        var pids: Set<pid_t> = []
        for info in windowInfoList {
            if let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
               let pid = info[kCGWindowOwnerPID as String] as? pid_t {
                pids.insert(pid)
            }
        }
        return pids
    }

    private func currentWindowLayersAndPIDs() -> (layers: [CGWindowID: Int], pids: Set<pid_t>) {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ([:], [])
        }
        var map: [CGWindowID: Int] = [:]
        var pids: Set<pid_t> = []
        for info in windowInfoList {
            if let wid = info[kCGWindowNumber as String] as? CGWindowID,
               let layer = info[kCGWindowLayer as String] as? Int {
                map[wid] = layer
                if layer == 0, let pid = info[kCGWindowOwnerPID as String] as? pid_t {
                    pids.insert(pid)
                }
            }
        }
        return (map, pids)
    }

    private func windowLayer(for wid: CGWindowID) -> Int? {
        guard let infoList = CGWindowListCopyWindowInfo([.optionIncludingWindow], wid) as? [[String: Any]],
              let info = infoList.first,
              let layer = info[kCGWindowLayer as String] as? Int else {
            return nil
        }
        return layer
    }

    // MARK: - WindowServer Fallback (when AX permission is not yet granted)

    private func getWindowsViaWindowServer(on screen: CGRect) -> [ManagedWindow] {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var results: [ManagedWindow] = []

        for info in windowInfoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else { continue }
            guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }

            let runningApp = NSRunningApplication(processIdentifier: pid)
            if let app = runningApp {
                if app.isHidden || app.bundleIdentifier == "dev.persona.mode" || app.activationPolicy != .regular {
                    continue
                }
            }

            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            guard screen.contains(center) else { continue }

            let appName = info[kCGWindowOwnerName as String] as? String ?? ""
            let bundleId = runningApp?.bundleIdentifier ?? appName

            let tilable = FloatRules.isTilable(
                windowID: wid,
                pid: pid,
                ownPID: ownPID,
                bundleId: bundleId,
                layer: layer,
                role: "AXWindow",
                subrole: "AXStandardWindow",
                isMinimized: false,
                isHidden: false,
                isFullscreen: false,
                size: bounds.size,
                isResizable: true,
                userFloatOverrides: userFloatOverrides,
                configFloatApps: configFloatApps
            )

            results.append(
                ManagedWindow(
                    id: wid,
                    pid: pid,
                    bundleId: bundleId,
                    title: appName,
                    frame: bounds,
                    layer: layer,
                    isTilable: tilable
                )
            )
        }

        return results
    }

    private func getFocusedWindowViaWindowServer() -> ManagedWindow? {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Prefer the frontmost application's top-most normal-layer window if available
        for pass in 0...1 {
            for info in windowInfoList {
                guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
                guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else { continue }
                if pass == 0, let fPid = frontPID, fPid != ownPID, pid != fPid {
                    continue
                }
                guard let wid = info[kCGWindowNumber as String] as? CGWindowID else { continue }
                guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }

                let runningApp = NSRunningApplication(processIdentifier: pid)
                if let app = runningApp {
                    if app.isHidden || app.bundleIdentifier == "dev.persona.mode" || app.activationPolicy != .regular {
                        continue
                    }
                }

                let appName = info[kCGWindowOwnerName as String] as? String ?? ""
                let bundleId = runningApp?.bundleIdentifier ?? appName

                let candidate = ManagedWindow(
                    id: wid,
                    pid: pid,
                    bundleId: bundleId,
                    title: appName,
                    frame: bounds,
                    layer: layer
                )

                if FloatRules.isEligibleForBorder(candidate, ownPID: ownPID) {
                    return candidate
                }
            }
        }

        return nil
    }
}

/// In-memory mock window provider for deterministic testing in selftest suites.
public final class MockAXWindowProvider: AXWindowProvider {
    public var windows: [ManagedWindow] = []
    public var focusedID: CGWindowID?
    public var setFrameCalls: [(id: CGWindowID, frame: CGRect)] = []

    public init(windows: [ManagedWindow] = [], focusedID: CGWindowID? = nil) {
        self.windows = windows
        self.focusedID = focusedID ?? windows.first?.id
    }

    public func getWindows(on screen: CGRect) -> [ManagedWindow] {
        windows.filter {
            let center = CGPoint(x: $0.frame.midX, y: $0.frame.midY)
            return screen.contains(center)
        }
    }

    public func getFocusedWindow() -> ManagedWindow? {
        guard let fid = focusedID else { return nil }
        return windows.first(where: { $0.id == fid })
    }

    public func setWindowFrame(window: ManagedWindow, frame: CGRect) -> Bool {
        setFrameCalls.append((id: window.id, frame: frame))
        if let idx = windows.firstIndex(where: { $0.id == window.id }) {
            windows[idx].frame = frame
        }
        return true
    }
}
