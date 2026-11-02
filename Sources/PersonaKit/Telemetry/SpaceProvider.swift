import AppKit
import CoreGraphics
import Foundation
import PersonaCore

private typealias CGSCopyManagedDisplaySpacesFunc = @convention(c) (Int32) -> Unmanaged<CFArray>?
private typealias CGSGetActiveSpaceFunc = @convention(c) (Int32) -> UInt64

@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32

@MainActor
public final class SpaceProvider {
    public static let shared = SpaceProvider()

    private var observer: NSObjectProtocol?
    private var isRunning = false

    private var copySpacesFunc: CGSCopyManagedDisplaySpacesFunc?
    private var getActiveSpaceFunc: CGSGetActiveSpaceFunc?
    private var isSymbolsAvailable = false

    public init() {
        resolveSymbols()
    }

    private func resolveSymbols() {
        let handle = dlopen(nil, RTLD_NOW)
        if let copySym = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
           let activeSym = dlsym(handle, "CGSGetActiveSpace") {
            copySpacesFunc = unsafeBitCast(copySym, to: CGSCopyManagedDisplaySpacesFunc.self)
            getActiveSpaceFunc = unsafeBitCast(activeSym, to: CGSGetActiveSpaceFunc.self)
            isSymbolsAvailable = true
        } else {
            isSymbolsAvailable = false
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        refresh()

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    public func stop() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observer = nil
        isRunning = false
    }

    public func refresh() {
        guard isSymbolsAvailable,
              let copyFunc = copySpacesFunc,
              let activeFunc = getActiveSpaceFunc else {
            AppState.shared.spaceSnapshot = .unavailable
            return
        }

        let cid = CGSMainConnectionID()
        guard let unmanaged = copyFunc(cid) else {
            AppState.shared.spaceSnapshot = .unavailable
            return
        }
        let displaysCF = unmanaged.takeRetainedValue()
        guard let displays = displaysCF as? [[String: Any]] else {
            AppState.shared.spaceSnapshot = .unavailable
            return
        }

        let activeSpaceID = activeFunc(cid)
        let snapshot = SpaceLayout.parse(displays: displays, activeSpaceID: activeSpaceID)
        AppState.shared.spaceSnapshot = snapshot
    }

    /// Switches to Space N (1...5) via synthetic Ctrl+N if enabled, otherwise sets hint.
    public func switchTo(spaceIndex: Int) {
        guard (1...5).contains(spaceIndex) else { return }

        // Check if "Switch to Desktop N" symbolic hotkey is enabled
        let domain = "com.apple.symbolichotkeys"
        let hotkeysDict = UserDefaults.standard.persistentDomain(forName: domain)?["AppleSymbolicHotKeys"] as? [String: Any]

        if SpaceLayout.isShortcutEnabled(desktop: spaceIndex, symbolicHotKeys: hotkeysDict) {
            if let keyCode = SpaceLayout.keyCode(forDesktop: spaceIndex) {
                let src = CGEventSource(stateID: .combinedSessionState)
                let keyDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keyCode), keyDown: false)
                keyDown?.flags = .maskControl
                keyUp?.flags = .maskControl

                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        } else {
            AppState.shared.hintMessage = "Enable 'Switch to Desktop \(spaceIndex)' in System Settings -> Keyboard Shortcuts -> Mission Control"
        }
    }
}
