import AppKit
import Foundation
import WebKit

/// Locked-down, transparent, zero-trace `WKWebView` surface (§3.2, §4.1, §4.2).
@MainActor
public final class WebSurfaceView: WKWebView, WKNavigationDelegate {
    public let surface: WebSurface
    public let isInteractiveSurface: Bool
    public let bridge: WebBridge
    public let schemeHandler: WebUISchemeHandler
    private var isTornDown = false

    public init(
        surface: WebSurface,
        interactive: Bool,
        debug: Bool = ProcessInfo.processInfo.environment["PERSONA_WEBUI_DEBUG"] == "1",
        schemeHandler: WebUISchemeHandler? = nil,
        onIntent: ((WebIntent) -> Void)? = nil
    ) {
        self.surface = surface
        self.isInteractiveSurface = interactive
        let resolvedSchemeHandler = schemeHandler ?? WebUISchemeHandler()
        self.schemeHandler = resolvedSchemeHandler
        let bridge = WebBridge(surface: surface, onIntent: onIntent)
        self.bridge = bridge

        let cfg = WKWebViewConfiguration()
        // ★ ZERO-TRACE: never write persistent WebKit caches or data stores to ~/Library
        cfg.websiteDataStore = .nonPersistent()
        cfg.setURLSchemeHandler(resolvedSchemeHandler, forURLScheme: "persona")
        cfg.userContentController.add(WeakScriptHandler(bridge), name: "persona")
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.preferences.isFraudulentWebsiteWarningEnabled = false
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = false

        super.init(frame: .zero, configuration: cfg)

        bridge.webView = self
        self.navigationDelegate = self

        // Transparent background configuration (verified in S-V2-1)
        self.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            self.underPageBackgroundColor = .clear
        }

        self.allowsMagnification = false
        self.allowsBackForwardNavigationGestures = false

        #if DEBUG
        if #available(macOS 13.3, *) {
            self.isInspectable = true
        }
        #else
        if debug {
            if #available(macOS 13.3, *) {
                self.isInspectable = true
            }
        }
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // ADR-V2-8: Keyboard input stays native; WebKit never steals first responder
    public override var acceptsFirstResponder: Bool {
        false
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        isInteractiveSurface
    }

    public override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.removeAllItems()
    }

    /// Loads `persona://app/<surface>.html` with optional query parameters.
    public func loadSurface(queryItems: [URLQueryItem] = []) {
        bridge.resetReady()
        var comps = URLComponents()
        comps.scheme = "persona"
        comps.host = "app"
        let pageName = (surface == .shapes) ? "dev-shapes" : surface.rawValue
        comps.path = "/\(pageName).html"
        if !queryItems.isEmpty {
            comps.queryItems = queryItems
        }
        if let url = comps.url {
            load(URLRequest(url: url))
        }
    }

    /// Deterministic teardown in the exact order mandated by §3.2.
    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true
        stopLoading()
        configuration.userContentController.removeAllScriptMessageHandlers()
        navigationDelegate = nil
        bridge.webView = nil
        bridge.onIntent = nil
        removeFromSuperview()
    }

    // MARK: - WKNavigationDelegate (Lockdown: only persona://app allowed)

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              url.scheme?.lowercased() == "persona",
              url.host?.lowercased() == "app",
              navigationAction.targetFrame != nil else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

