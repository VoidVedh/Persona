import Foundation

public enum SystemAdapterError: Error, Equatable {
    case notImplemented
    case commandFailed(String)
    case timedOut
}

public protocol SystemAdapter {
    func readDockAutohide() -> OriginalValue<Bool>
    func readMenuBarKeys() -> (hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>)
    func readScripted() -> (dock: Bool?, menuBar: Bool?)
    func readWallpapers() -> [WallpaperSnapshot]

    func setDockAutohide(_ v: Bool) throws
    func setMenuBarAutohide(_ v: Bool) throws
    func deleteDockAutohideKey() throws
    func setMenuBarKeys(hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) throws
    func setWallpapers(_ wallpapers: [WallpaperSnapshot]) throws
    func isStable() -> Bool
}
