import CoreGraphics
import Foundation

/// Events emitted across the Persona system.
public enum PersonaEvent: Equatable {
    case windowCreated(CGWindowID)
    case windowDestroyed(CGWindowID)
    case focusChanged(pid: pid_t, windowID: CGWindowID?)
    case frameChangedExternally(windowID: CGWindowID, frame: CGRect)
    case spaceChanged
    case screensChanged
    case axTrustChanged(Bool)
    case tileRequested
    case reloadThemeRequested

    public static func == (lhs: PersonaEvent, rhs: PersonaEvent) -> Bool {
        switch (lhs, rhs) {
        case (.windowCreated(let a), .windowCreated(let b)):
            return a == b
        case (.windowDestroyed(let a), .windowDestroyed(let b)):
            return a == b
        case (.focusChanged(let p1, let w1), .focusChanged(let p2, let w2)):
            return p1 == p2 && w1 == w2
        case (.frameChangedExternally(let w1, let f1), .frameChangedExternally(let w2, let f2)):
            return w1 == w2 && f1 == f2
        case (.spaceChanged, .spaceChanged):
            return true
        case (.screensChanged, .screensChanged):
            return true
        case (.axTrustChanged(let a), .axTrustChanged(let b)):
            return a == b
        case (.tileRequested, .tileRequested):
            return true
        case (.reloadThemeRequested, .reloadThemeRequested):
            return true
        default:
            return false
        }
    }
}

/// Central in-process event bus for Persona subsystem notifications.
@MainActor
public final class EventBus {
    public static let shared = EventBus()

    public typealias SubscriptionToken = UUID
    private var subscribers: [SubscriptionToken: (PersonaEvent) -> Void] = [:]

    public init() {}

    @discardableResult
    public func subscribe(_ handler: @escaping @MainActor (PersonaEvent) -> Void) -> SubscriptionToken {
        let token = UUID()
        subscribers[token] = handler
        return token
    }

    public func unsubscribe(_ token: SubscriptionToken) {
        subscribers.removeValue(forKey: token)
    }

    public func publish(_ event: PersonaEvent) {
        for handler in subscribers.values {
            handler(event)
        }
    }
}
