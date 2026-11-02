import AppKit
import PersonaCore

/// Snapshot of one physical display, including notch metrics. Pure value type so layout code and
/// self-tests can build synthetic screens without a window server.
public struct ScreenModel: Equatable {
    public var id: CGDirectDisplayID
    public var uuid: String
    public var frame: CGRect
    public var visibleFrame: CGRect
    /// `safeAreaInsets.top` — non-zero on notched displays.
    public var safeTop: CGFloat
    /// `auxiliaryTopLeftArea` (usable menu-bar area left of the notch), screen coordinates.
    public var auxLeft: CGRect?
    /// `auxiliaryTopRightArea` (usable menu-bar area right of the notch), screen coordinates.
    public var auxRight: CGRect?
    public var backingScale: CGFloat
    public var isPrimary: Bool

    public init(
        id: CGDirectDisplayID,
        uuid: String,
        frame: CGRect,
        visibleFrame: CGRect? = nil,
        safeTop: CGFloat = 0,
        auxLeft: CGRect? = nil,
        auxRight: CGRect? = nil,
        backingScale: CGFloat = 2,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.uuid = uuid
        self.frame = frame
        self.visibleFrame = visibleFrame ?? frame
        self.safeTop = safeTop
        self.auxLeft = auxLeft
        self.auxRight = auxRight
        self.backingScale = backingScale
        self.isPrimary = isPrimary
    }

    @MainActor
    public init?(screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        var uuidString = "display-\(displayID)"
        if let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let str = CFUUIDCreateString(nil, cfUUID) as String? {
            uuidString = str
        }
        self.init(
            id: displayID,
            uuid: uuidString,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeTop: screen.safeAreaInsets.top,
            auxLeft: screen.auxiliaryTopLeftArea,
            auxRight: screen.auxiliaryTopRightArea,
            backingScale: screen.backingScaleFactor,
            isPrimary: CGDisplayIsMain(displayID) != 0
        )
    }

    /// All attached displays, primary first (then by display id for stable ordering).
    @MainActor
    public static func current() -> [ScreenModel] {
        NSScreen.screens
            .compactMap { ScreenModel(screen: $0) }
            .sorted { lhs, rhs in
                if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
                return lhs.id < rhs.id
            }
    }

    /// Whether the display has a camera notch.
    public var hasNotch: Bool { safeTop > 0 && auxLeft != nil && auxRight != nil }
}

/// Publishes display configuration changes (`didChangeScreenParametersNotification`).
@MainActor
public final class ScreenObserver {
    private var token: NSObjectProtocol?

    public init(onChange: @escaping ([ScreenModel]) -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onChange(ScreenModel.current()) }
        }
    }

    public func invalidate() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}
