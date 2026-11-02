import AppKit
import CoreText
import SwiftUI

/// Bundled OFL fonts (Rajdhani for body, Bebas Neue for display), registered **process-scoped** so
/// nothing is installed on the system (zero trace).
public enum Fonts {
    public static let bebasName = "BebasNeue-Regular"
    public static let rajdhaniSemiBoldName = "Rajdhani-SemiBold"
    public static let rajdhaniBoldName = "Rajdhani-Bold"

    private static var registered = false

    /// Registers every `.ttf` found in `<resources>/fonts` for this process. Safe to call repeatedly.
    /// Returns the number of font files registered this call.
    @discardableResult
    public static func register() -> Int {
        guard !registered else { return 0 }
        registered = true
        guard let dir = ResourceLocator.resourceDirectory()?.appendingPathComponent("fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return 0
        }
        var count = 0
        for url in files where url.pathExtension.lowercased() == "ttf" {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { count += 1 }
        }
        return count
    }

    public static func isAvailable(_ postScriptName: String) -> Bool {
        NSFont(name: postScriptName, size: 12) != nil
    }

    /// Display face (big numerals, app name): Bebas Neue → Avenir Next Condensed → rounded system.
    public static func display(_ size: CGFloat) -> Font {
        if isAvailable(bebasName) { return .custom(bebasName, size: size) }
        if isAvailable("AvenirNextCondensed-Heavy") { return .custom("AvenirNextCondensed-Heavy", size: size) }
        return .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Body face: Rajdhani SemiBold/Bold → Avenir Next Condensed → rounded system.
    public static func body(_ size: CGFloat, bold: Bool = false) -> Font {
        let name = bold ? rajdhaniBoldName : rajdhaniSemiBoldName
        if isAvailable(name) { return .custom(name, size: size) }
        let fallback = bold ? "AvenirNextCondensed-Bold" : "AvenirNextCondensed-DemiBold"
        if isAvailable(fallback) { return .custom(fallback, size: size) }
        return .system(size: size, weight: bold ? .bold : .semibold, design: .rounded)
    }
}
