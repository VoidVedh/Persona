import AppKit
import Foundation

public protocol FocusTitleProvider: AnyObject {
    func title(for pid: pid_t) -> String?
}

public final class NullTitleProvider: FocusTitleProvider {
    public init() {}
    public func title(for pid: pid_t) -> String? { nil }
}

@MainActor
public final class FocusTracker {
    public static let shared = FocusTracker()

    public var titleProvider: FocusTitleProvider = NullTitleProvider()
    private var observer: NSObjectProtocol?
    private var eventSub: EventBus.SubscriptionToken?
    private var isRunning = false

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // Capture initial active app
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            updateApp(currentApp)
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                self?.updateApp(app)
                if app.bundleIdentifier != "dev.persona.mode" &&
                   app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                    EventBus.shared.publish(.focusChanged(pid: app.processIdentifier, windowID: nil))
                }
            }
        }

        eventSub = EventBus.shared.subscribe { [weak self] event in
            guard let self = self else { return }
            if case .focusChanged(let pid, _) = event {
                let title = self.titleProvider.title(for: pid) ?? ""
                AppState.shared.focusedTitle = title
            }
        }
    }

    public func stop() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observer = nil

        if let sub = eventSub {
            EventBus.shared.unsubscribe(sub)
        }
        eventSub = nil
        isRunning = false
    }

    private func updateApp(_ app: NSRunningApplication) {
        if app.bundleIdentifier == "dev.persona.mode" ||
           app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }
        let name = (app.localizedName ?? "APP").uppercased()
        AppState.shared.focusedApp = name
        let title = titleProvider.title(for: app.processIdentifier) ?? ""
        AppState.shared.focusedTitle = title
    }
}
