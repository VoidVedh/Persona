import AppKit
import CoreGraphics
import Foundation
import PersonaCore

extension RealSystemAdapter {
    public func setDockAutohide(_ v: Bool) throws {
        let script = "tell application \"System Events\" to set autohide of dock preferences to \(v)"
        let res = ShellRunner.runAppleScript(script, timeout: 3)
        let readBack = ShellRunner.runAppleScript("tell application \"System Events\" to get autohide of dock preferences", timeout: 2)
        let actual = readBack.out.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if res.status != 0 || actual != "\(v)" {
            // Fallback / macOS 26 direct: defaults write + killall Dock
            let writeRes = ShellRunner.run("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", v ? "true" : "false"], timeout: 3)
            _ = ShellRunner.run("/usr/bin/killall", ["Dock"], timeout: 3)
            if writeRes.status != 0 {
                throw SystemAdapterError.commandFailed("Failed to set dock autohide via defaults: \(writeRes.err)")
            }
        }
    }

    public func deleteDockAutohideKey() throws {
        _ = ShellRunner.run("/usr/bin/defaults", ["delete", "com.apple.dock", "autohide"], timeout: 3)
        _ = ShellRunner.run("/usr/bin/killall", ["Dock"], timeout: 3)
        CFPreferencesSetAppValue("autohide" as CFString, nil, "com.apple.dock" as CFString)
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
    }

    public func setMenuBarAutohide(_ v: Bool) throws {
        let script = "tell application \"System Events\" to set autohide menu bar of dock preferences to \(v)"
        let res = ShellRunner.runAppleScript(script, timeout: 3)
        if res.status != 0 {
            // Fallback: defaults write
            let writeRes = ShellRunner.run("/usr/bin/defaults", ["write", "NSGlobalDomain", "_HIHideMenuBar", "-bool", v ? "true" : "false"], timeout: 3)
            if writeRes.status != 0 {
                throw SystemAdapterError.commandFailed("Failed to set menu bar autohide via defaults: \(writeRes.err)")
            }
        }
    }

    public func setMenuBarKeys(hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) throws {
        if hide.present, let val = hide.value {
            _ = ShellRunner.run("/usr/bin/defaults", ["write", "NSGlobalDomain", "_HIHideMenuBar", "-bool", val ? "true" : "false"], timeout: 3)
        } else {
            _ = ShellRunner.run("/usr/bin/defaults", ["delete", "NSGlobalDomain", "_HIHideMenuBar"], timeout: 3)
            CFPreferencesSetAppValue("_HIHideMenuBar" as CFString, nil, kCFPreferencesAnyApplication)
        }

        if fullscreen.present, let val = fullscreen.value {
            _ = ShellRunner.run("/usr/bin/defaults", ["write", "NSGlobalDomain", "AppleMenuBarVisibleInFullscreen", "-bool", val ? "true" : "false"], timeout: 3)
        } else {
            _ = ShellRunner.run("/usr/bin/defaults", ["delete", "NSGlobalDomain", "AppleMenuBarVisibleInFullscreen"], timeout: 3)
            CFPreferencesSetAppValue("AppleMenuBarVisibleInFullscreen" as CFString, nil, kCFPreferencesAnyApplication)
        }
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    }

    public func setWallpapers(_ wallpapers: [WallpaperSnapshot]) throws {
        for screen in NSScreen.screens {
            guard let screenNum = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayID = CGDirectDisplayID(screenNum.uint32Value)
            let displayUUID: String
            if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) {
                let cfStr = CFUUIDCreateString(nil, uuidRef.takeRetainedValue())
                displayUUID = (cfStr as String?) ?? "\(displayID)"
            } else {
                displayUUID = "\(displayID)"
            }

            if let match = wallpapers.first(where: { $0.displayUUID == displayUUID }), match.isRestorable, let url = URL(string: match.url) {
                var opts: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
                if let scaling = match.options?.imageScaling {
                    opts[.imageScaling] = NSNumber(value: scaling)
                }
                if let clipping = match.options?.allowClipping {
                    opts[.allowClipping] = NSNumber(value: clipping)
                }
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: opts)
            }
        }
    }
}
