import AppKit
import Foundation
import WebKit

/// Runtime transparency check for `WKWebView` used by ADR-V2-9 (`WebContentFactory` fallback).
@MainActor
public enum WebTransparencyCheck {
    public struct Result: Codable, Equatable {
        public let drawsBackgroundKVC: Bool
        public let underPageClear: Bool
        public let alphaAtCorner: Double
        public let chosen: String
        public let passed: Bool

        public init(
            drawsBackgroundKVC: Bool,
            underPageClear: Bool,
            alphaAtCorner: Double,
            chosen: String,
            passed: Bool
        ) {
            self.drawsBackgroundKVC = drawsBackgroundKVC
            self.underPageClear = underPageClear
            self.alphaAtCorner = alphaAtCorner
            self.chosen = chosen
            self.passed = passed
        }
    }

    private static var cachedPasses: Bool?

    /// Fast startup check verifying that `WKWebView` honors `drawsBackground = false` + `underPageBackgroundColor = .clear`.
    public static func passes() -> Bool {
        if let cached = cachedPasses {
            return cached
        }
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 64, height: 64), configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")
        var underClear = false
        if #available(macOS 12.0, *) {
            web.underPageBackgroundColor = .clear
            underClear = (web.underPageBackgroundColor == .clear)
        }
        let kvc = (web.value(forKey: "drawsBackground") as? Bool) == false
        let ok = kvc || underClear
        cachedPasses = ok
        return ok
    }
}

