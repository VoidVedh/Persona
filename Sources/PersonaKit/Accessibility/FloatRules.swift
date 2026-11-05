import CoreGraphics
import Foundation

/// Rules governing whether a window should be managed by the tiling engine or active border tracker.
public enum FloatRules {
    /// Default bundle identifiers that always float.
    public static let defaultFloatApps: Set<String> = [
        "com.apple.systempreferences",
        "com.apple.SystemSettings",
        "com.apple.calculator",
        "com.apple.archiveutility",
        "dev.persona.mode",
        "com.apple.installer",
        "com.apple.keychainaccess",
        "com.apple.quicklook.ui.helper",
        "com.apple.ColorSampler",
        "com.apple.ScreenSharing"
    ]

    /// Evaluates whether a given window is eligible for the active-window border overlay.
    /// Enforces self-exclusion, normal window layer (0), non-minimized/hidden/fullscreen, and popup filtering.
    public static func isEligibleForBorder(
        _ win: ManagedWindow,
        ownPID: pid_t = ProcessInfo.processInfo.processIdentifier
    ) -> Bool {
        // Strictly exclude PersonaMode's own PID and bundle identifier
        if win.pid == ownPID || win.bundleId == "dev.persona.mode" || win.bundleId == "PersonaMode" {
            return false
        }

        // Strictly require normal window layer (kCGWindowLayer == 0)
        if win.layer != 0 {
            return false
        }

        // Exclude minimized, hidden, or fullscreen windows
        if win.isMinimized || win.isHidden || win.isFullscreen {
            return false
        }

        // Exclude non-window roles or system dialogs/tooltips
        if !win.role.isEmpty && win.role != "AXWindow" {
            return false
        }
        if win.subrole == "AXTooltip" || win.subrole == "AXUnknown" {
            return false
        }

        // Guard against tiny utility popups/tooltips (< 100x50)
        if win.frame.width < 100 || win.frame.height < 50 {
            return false
        }

        return true
    }

    /// Evaluates whether a given window is eligible for automatic layout tiling.
    public static func isTilable(
        windowID: CGWindowID,
        pid: pid_t = 0,
        ownPID: pid_t = ProcessInfo.processInfo.processIdentifier,
        bundleId: String,
        layer: Int = 0,
        role: String,
        subrole: String,
        isMinimized: Bool,
        isHidden: Bool = false,
        isFullscreen: Bool,
        size: CGSize,
        isResizable: Bool,
        userFloatOverrides: Set<CGWindowID> = [],
        configFloatApps: [String] = []
    ) -> Bool {
        // User manual toggle (Ctrl+Opt+F)
        if userFloatOverrides.contains(windowID) {
            return false
        }

        // Strictly exclude Persona Mode windows (own PID or bundle identifier)
        if (pid != 0 && pid == ownPID) || bundleId == "dev.persona.mode" || bundleId == "PersonaMode" {
            return false
        }

        // Strictly require normal window layer (kCGWindowLayer == 0)
        if layer != 0 {
            return false
        }

        // Floating apps list
        if defaultFloatApps.contains(bundleId) || configFloatApps.contains(bundleId) {
            return false
        }

        // Only standard top-level windows can be tiled
        if role != "AXWindow" || subrole != "AXStandardWindow" {
            return false
        }

        // Skip minimized, hidden, or full-screen spaces
        if isMinimized || isHidden || isFullscreen {
            return false
        }

        // Minimum sensible size for a tilable app window (filters popups/dialogs/tooltips)
        if size.width < 200 || size.height < 120 {
            return false
        }

        // Must support resizing
        if !isResizable {
            return false
        }

        return true
    }

    /// Evaluates whether a `ManagedWindow` is eligible for automatic layout tiling.
    public static func isEligibleForTiling(
        _ win: ManagedWindow,
        ownPID: pid_t = ProcessInfo.processInfo.processIdentifier,
        userFloatOverrides: Set<CGWindowID> = [],
        configFloatApps: [String] = []
    ) -> Bool {
        guard win.isTilable else { return false }
        return isTilable(
            windowID: win.id,
            pid: win.pid,
            ownPID: ownPID,
            bundleId: win.bundleId,
            layer: win.layer,
            role: win.role,
            subrole: win.subrole,
            isMinimized: win.isMinimized,
            isHidden: win.isHidden,
            isFullscreen: win.isFullscreen,
            size: win.frame.size,
            isResizable: win.isResizable,
            userFloatOverrides: userFloatOverrides,
            configFloatApps: configFloatApps
        )
    }
}
