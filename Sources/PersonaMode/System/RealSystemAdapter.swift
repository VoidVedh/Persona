import AppKit
import CoreGraphics
import Foundation
import PersonaCore

public final class RealSystemAdapter: SystemAdapter {
    public let skipAppleScript: Bool

    public init(skipAppleScript: Bool = false) {
        self.skipAppleScript = skipAppleScript
    }

    public func readDockAutohide() -> OriginalValue<Bool> {
        let key = "autohide" as CFString
        let domain = "com.apple.dock" as CFString
        guard let val = CFPreferencesCopyAppValue(key, domain) else {
            return OriginalValue(present: false, value: nil)
        }
        if let boolVal = val as? Bool {
            return OriginalValue(present: true, value: boolVal)
        }
        if let numVal = val as? NSNumber {
            return OriginalValue(present: true, value: numVal.boolValue)
        }
        return OriginalValue(present: true, value: nil)
    }

    public func readMenuBarKeys() -> (hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) {
        let domain = kCFPreferencesAnyApplication

        let hideVal = CFPreferencesCopyAppValue("_HIHideMenuBar" as CFString, domain)
        let hideResult: OriginalValue<Bool>
        if let val = hideVal {
            let b = (val as? Bool) ?? (val as? NSNumber)?.boolValue
            hideResult = OriginalValue(present: true, value: b)
        } else {
            hideResult = OriginalValue(present: false, value: nil)
        }

        let fsVal = CFPreferencesCopyAppValue("AppleMenuBarVisibleInFullscreen" as CFString, domain)
        let fsResult: OriginalValue<Bool>
        if let val = fsVal {
            let b = (val as? Bool) ?? (val as? NSNumber)?.boolValue
            fsResult = OriginalValue(present: true, value: b)
        } else {
            fsResult = OriginalValue(present: false, value: nil)
        }

        return (hideResult, fsResult)
    }

    public func readScripted() -> (dock: Bool?, menuBar: Bool?) {
        if skipAppleScript {
            return (nil, nil)
        }

        var dockBool: Bool?
        let dockRes = ShellRunner.runAppleScript("tell application \"System Events\" to get autohide of dock preferences")
        if dockRes.status == 0 {
            let trimmed = dockRes.out.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed == "true" { dockBool = true }
            else if trimmed == "false" { dockBool = false }
        }

        var menuBarBool: Bool?
        let mbRes = ShellRunner.runAppleScript("tell application \"System Events\" to get autohide menu bar of dock preferences")
        if mbRes.status == 0 {
            let trimmed = mbRes.out.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed == "true" { menuBarBool = true }
            else if trimmed == "false" { menuBarBool = false }
        }

        return (dockBool, menuBarBool)
    }

    public func readWallpapers() -> [WallpaperSnapshot] {
        var snapshots: [WallpaperSnapshot] = []

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

            let name = screen.localizedName
            let imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
            let urlString = imageURL?.absoluteString ?? ""

            var isRestorable = false
            if let url = imageURL, url.isFileURL {
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                let ext = url.pathExtension.lowercased()
                let validExtensions = ["heic", "jpg", "jpeg", "png", "tiff"]
                isRestorable = exists && !isDir.boolValue && validExtensions.contains(ext)
            }

            var wallpaperOpts: WallpaperOptions?
            if let opts = NSWorkspace.shared.desktopImageOptions(for: screen) {
                let scaling = (opts[NSWorkspace.DesktopImageOptionKey.imageScaling] as? NSNumber)?.intValue
                let clipping = (opts[NSWorkspace.DesktopImageOptionKey.allowClipping] as? NSNumber)?.boolValue
                let colorHex: String? = nil
                wallpaperOpts = WallpaperOptions(imageScaling: scaling, allowClipping: clipping, fillColorHex: colorHex)
            }

            snapshots.append(WallpaperSnapshot(
                displayUUID: displayUUID,
                name: name,
                url: urlString,
                options: wallpaperOpts,
                isRestorable: isRestorable
            ))
        }

        return snapshots
    }


    public func isStable() -> Bool {
        return true
    }
}
