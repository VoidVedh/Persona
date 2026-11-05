import AppKit
import Foundation

public struct AppEntry: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let bundleId: String
    public let url: URL

    public init(id: String, name: String, bundleId: String, url: URL) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.url = url
    }

    public static func == (lhs: AppEntry, rhs: AppEntry) -> Bool {
        lhs.id == rhs.id && lhs.bundleId == rhs.bundleId
    }
}

public struct ActionEntry: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let detail: String
    public let iconName: String
    public let isDestructive: Bool
    public let command: PersonaCommand

    public init(
        id: String,
        name: String,
        detail: String = "",
        iconName: String = "bolt",
        isDestructive: Bool = false,
        command: PersonaCommand
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.iconName = iconName
        self.isDestructive = isDestructive
        self.command = command
    }
}

public enum LauncherItem: Identifiable, Equatable {
    case app(AppEntry)
    case action(ActionEntry)

    public var id: String {
        switch self {
        case .app(let entry):
            return "app:\(entry.id)"
        case .action(let entry):
            return "action:\(entry.id)"
        }
    }

    public var name: String {
        switch self {
        case .app(let entry):
            return entry.name
        case .action(let entry):
            return entry.name
        }
    }

    public var isAction: Bool {
        switch self {
        case .app: return false
        case .action: return true
        }
    }
}
