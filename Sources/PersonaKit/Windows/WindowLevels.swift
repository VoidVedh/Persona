import AppKit
import PersonaCore

/// Window levels used by Persona. Always derived from the system constants, never hardcoded (§5).
public enum WindowLevels {
    /// Above the wallpaper, below Finder desktop icons and every app window.
    public static var desktopOverlay: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
    }

    /// Top bar level: `.statusBar` (25) per the project spec.
    public static var topBar: NSWindow.Level { .statusBar }

    /// Top bar level for a configured `BarLevel`.
    public static func topBar(for level: BarLevel) -> NSWindow.Level {
        switch level {
        case .statusBar:
            return .statusBar
        case .mainMenuMinusOne:
            return NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        }
    }

    /// Launcher: above the bar, below real pop-up menus.
    public static var launcher: NSWindow.Level {
        NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
    }

    /// Active-window border ring.
    public static var border: NSWindow.Level { .floating }
}
