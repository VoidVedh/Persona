import Foundation

public enum Mutation: Codable, Equatable {
    case dockAutohide(Bool)
    case menuBarAutohide(Bool)
    case systemWallpaper(path: String)
    case terminalProfile(name: String)
    case tempDir(path: String)
}
