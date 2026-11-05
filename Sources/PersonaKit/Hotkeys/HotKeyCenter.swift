import Carbon
import Foundation
import PersonaCore

private func hotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let theEvent = theEvent else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr {
        HotKeyCenter.shared.dispatchHotKey(id: hotKeyID.id)
    }

    return noErr
}

/// System-wide global hotkey manager implemented with the Carbon Events API.
public final class HotKeyCenter: @unchecked Sendable {
    public static let shared = HotKeyCenter()

    public static let signature = OSType(0x5052534E) // 'PRSN'

    private var eventHandlerRef: EventHandlerRef?
    private var registeredHotKeys: [UInt32: (chord: String, ref: EventHotKeyRef, command: PersonaCommand)] = [:]
    private var nextID: UInt32 = 1

    public init() {}

    public var registeredCount: Int {
        registeredHotKeys.count
    }

    @discardableResult
    public func registerAll(config: AppConfig = AppConfig()) -> [String: Int32] {
        unregisterAll()

        let bindings: [(String, PersonaCommand)] = [
            (config.hotkeys.launcher, .toggleLauncher),
            (config.hotkeys.tile, .tileNow),
            (config.hotkeys.toggleFloat, .toggleFloatFocused),
            (config.hotkeys.terminal, .openTerminal),
            (config.hotkeys.panic, .panic),
            (config.hotkeys.space1, .switchSpace(1)),
            (config.hotkeys.space2, .switchSpace(2)),
            (config.hotkeys.space3, .switchSpace(3)),
            (config.hotkeys.space4, .switchSpace(4)),
            (config.hotkeys.space5, .switchSpace(5))
        ]

        var statuses: [String: Int32] = [:]
        var errors: [String] = []

        for (chord, command) in bindings where !chord.isEmpty {
            let status = register(chord: chord, command: command)
            statuses[chord] = status
            if status != noErr {
                errors.append("\(chord) (OSStatus \(status))")
            }
        }

        let capturedErrors = errors
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                AppState.shared.hotkeyErrors = capturedErrors
            }
        } else {
            DispatchQueue.main.async {
                AppState.shared.hotkeyErrors = capturedErrors
            }
        }

        return statuses
    }

    public func registerDefaults() {
        _ = registerAll(config: AppConfig())
    }

    @discardableResult
    public func register(chord: String, command: PersonaCommand) -> OSStatus {
        installHandlerIfNeeded()

        guard let (keyCode, modifiers) = parseChord(chord) else {
            return OSStatus(eventNotHandledErr)
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
        nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref = ref {
            registeredHotKeys[hotKeyID.id] = (chord: chord, ref: ref, command: command)
        }

        return status
    }

    public func unregisterAll() {
        for entry in registeredHotKeys.values {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotKeys.removeAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    public func testStatus(config: AppConfig = AppConfig()) -> [String: Int32] {
        let result = registerAll(config: config)
        unregisterAll()
        return result
    }

    fileprivate func dispatchHotKey(id: UInt32) {
        guard let entry = registeredHotKeys[id] else { return }

        if entry.command == .panic {
            _ = RestoreService.shared?.restoreAll(reason: .panic)
            exit(0)
        }

        DispatchQueue.main.async {
            CommandRouter.shared.send(entry.command)
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    public func parseChord(_ chord: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        let parts = chord.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }

        var mods: UInt32 = 0
        var keyStr = ""

        for part in parts {
            switch part {
            case "cmd", "command":
                mods |= UInt32(cmdKey)
            case "opt", "alt", "option":
                mods |= UInt32(optionKey)
            case "ctrl", "control":
                mods |= UInt32(controlKey)
            case "shift":
                mods |= UInt32(shiftKey)
            default:
                keyStr = part
            }
        }

        guard let keyCode = keyCodeFor(keyStr) else { return nil }
        return (keyCode, mods)
    }

    public func keyCodeFor(_ key: String) -> UInt32? {
        switch key.lowercased() {
        case "space": return 0x31
        case "return", "enter": return 0x24
        case "escape", "esc": return 0x35
        case "tab": return 0x30
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "9": return 0x19
        case "7": return 0x1A
        case "8": return 0x1C
        case "0": return 0x1D
        case "o": return 0x1F
        case "u": return 0x20
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "k": return 0x28
        case "n": return 0x2D
        case "m": return 0x2E
        default: return nil
        }
    }
}
