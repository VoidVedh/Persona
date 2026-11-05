@preconcurrency import ApplicationServices
@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import Foundation

private func axObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let instance = Unmanaged<AXWindowObserver>.fromOpaque(refcon).takeUnretainedValue()
    instance.handleNotification(element: element, notification: notification as String)
}

/// Watches application window lifecycle and movement events across running processes.
public final class AXWindowObserver: @unchecked Sendable {
    public static let shared = AXWindowObserver()

    private var observers: [pid_t: (observer: AXObserver, source: CFRunLoopSource)] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isRunning = false

    private let observedNotifications: [String] = [
        kAXWindowCreatedNotification,
        kAXUIElementDestroyedNotification,
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification
    ]

    public init() {}

    public func start() {
        guard !isRunning else { return }
        guard AXPermission.shared.isTrusted else { return }
        isRunning = true

        let center = NSWorkspace.shared.notificationCenter
        let launchObs = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.attachObserver(for: app, attempt: 1)
        }
        workspaceObservers.append(launchObs)

        let termObs = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.detachObserver(for: app.processIdentifier)
        }
        workspaceObservers.append(termObs)

        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular {
                attachObserver(for: app, attempt: 1)
            }
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers.removeAll()

        for pid in Array(observers.keys) {
            detachObserver(for: pid)
        }
        observers.removeAll()
    }

    private func attachObserver(for app: NSRunningApplication, attempt: Int) {
        let pid = app.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }
        guard app.bundleIdentifier != "dev.persona.mode" else { return }
        guard observers[pid] == nil else { return }

        AXWorker.shared.perform { [weak self] in
            guard let self = self, self.isRunning else { return }
            var obsRef: AXObserver?
            let refcon = Unmanaged.passUnretained(self).toOpaque()

            let status = AXObserverCreate(pid, axObserverCallback, &obsRef)
            guard status == .success, let obs = obsRef else {
                if attempt < 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                        guard let self = self, self.isRunning else { return }
                        self.attachObserver(for: app, attempt: attempt + 1)
                    }
                }
                return
            }

            let appElement = AXUIElementCreateApplication(pid)
            var registeredCount = 0
            for notifName in self.observedNotifications {
                if AXObserverAddNotification(obs, appElement, notifName as CFString, refcon) == .success {
                    registeredCount += 1
                }
            }

            if registeredCount == 0 && attempt < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                    guard let self = self, self.isRunning else { return }
                    self.attachObserver(for: app, attempt: attempt + 1)
                }
                return
            }

            let source = AXObserverGetRunLoopSource(obs)
            if let targetRL = AXWorker.shared.targetRunLoop {
                CFRunLoopAddSource(targetRL, source, .defaultMode)
            }

            DispatchQueue.main.async {
                guard self.isRunning else { return }
                self.observers[pid] = (observer: obs, source: source)
            }
        }
    }

    private func detachObserver(for pid: pid_t) {
        guard let entry = observers.removeValue(forKey: pid) else { return }

        AXWorker.shared.perform {
            if let targetRL = AXWorker.shared.targetRunLoop {
                CFRunLoopRemoveSource(targetRL, entry.source, .defaultMode)
            }
        }
    }

    fileprivate func handleNotification(element: AXUIElement, notification: String) {
        var pid: pid_t = 0
        _ = AXUIElementGetPid(element, &pid)
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }

        let wid = AXPrivate.windowID(for: element)

        DispatchQueue.main.async {
            switch notification {
            case kAXWindowCreatedNotification:
                if let id = wid {
                    EventBus.shared.publish(.windowCreated(id))
                }
            case kAXUIElementDestroyedNotification:
                if let id = wid {
                    EventBus.shared.publish(.windowDestroyed(id))
                }
            case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
                EventBus.shared.publish(.focusChanged(pid: pid, windowID: wid))
            case kAXWindowMovedNotification, kAXWindowResizedNotification:
                if let id = wid,
                   let pos = AXPrivate.copyPointAttribute(element: element, attribute: kAXPositionAttribute),
                   let size = AXPrivate.copySizeAttribute(element: element, attribute: kAXSizeAttribute) {
                    let frame = CGRect(origin: pos, size: size)
                    EventBus.shared.publish(.frameChangedExternally(windowID: id, frame: frame))
                }
            case kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification:
                EventBus.shared.publish(.tileRequested)
            default:
                break
            }
        }
    }
}
