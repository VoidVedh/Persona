import Foundation
import WebKit

public enum WebSurface: String, Codable, Equatable, CaseIterable {
    case topbar
    case hud
    case launcher
    case wallpaper
    case shapes
}

/// Strictly whitelisted inbound intents from WebKit surfaces (§4.1, §4.3).
public enum WebIntent: Equatable {
    case ready(WebSurface)
    case exit
    case switchSpace(Int)
    case launcherActivate(Int, reveal: Bool)
    case launcherHover(Int)
    case log(String)

    /// Pure decoder validating origin scheme, payload bounds, and message type whitelist.
    public static func decode(
        body: Any,
        scheme: String?,
        surfaceFallback: WebSurface = .topbar
    ) -> WebIntent? {
        guard scheme?.lowercased() == "persona" else { return nil }
        guard let dict = body as? [String: Any], dict.count <= 16 else { return nil }

        if let v = dict["v"] as? Int, v != 1 {
            return nil
        }
        guard let type = dict["type"] as? String, type.count <= 64 else { return nil }
        let payload = dict["payload"] as? [String: Any] ?? [:]
        guard payload.count <= 16 else { return nil }

        switch type {
        case "ready":
            if let rawSurface = payload["surface"] as? String,
               let parsed = WebSurface(rawValue: rawSurface) {
                return .ready(parsed)
            }
            return .ready(surfaceFallback)

        case "exit":
            return .exit

        case "switchSpace":
            guard let n = payload["n"] as? Int, (1...16).contains(n) else { return nil }
            return .switchSpace(n)

        case "launcherActivate":
            guard let idx = payload["index"] as? Int, (0...500).contains(idx) else { return nil }
            let reveal = (payload["reveal"] as? Bool) ?? false
            return .launcherActivate(idx, reveal: reveal)

        case "launcherHover":
            guard let idx = payload["index"] as? Int, (0...500).contains(idx) else { return nil }
            return .launcherHover(idx)

        case "log":
            guard let msg = payload["message"] as? String, msg.count <= 1024 else { return nil }
            return .log(msg)

        default:
            return nil
        }
    }
}

/// Typed Swift <-> JS message bridge with pre-ready patch queueing and shallow merge (§3.2, §4.3).
@MainActor
public final class WebBridge: NSObject, WKScriptMessageHandler {
    public let surface: WebSurface
    public weak var webView: WKWebView?
    public var onIntent: ((WebIntent) -> Void)?

    public private(set) var isReady: Bool = false
    public private(set) var pendingPatch: [String: Any] = [:]

    public init(surface: WebSurface, onIntent: ((WebIntent) -> Void)? = nil) {
        self.surface = surface
        self.onIntent = onIntent
        super.init()
    }

    /// Queues or dispatches a state patch to the surface. If the page has not yet posted `ready`,
    /// patches are shallow-merged into `pendingPatch` (latest key wins) and flushed on `ready`.
    public func publish(_ patch: [String: Any], to targetSurface: WebSurface? = nil) {
        let dest = targetSurface ?? surface
        guard dest == surface else { return }

        if !isReady {
            for (k, v) in patch {
                pendingPatch[k] = v
            }
            return
        }

        sendPatchNow(patch)
    }

    /// Marks the bridge ready and flushes any queued patches.
    public func markReady() {
        guard !isReady else { return }
        isReady = true
        if !pendingPatch.isEmpty {
            let queued = pendingPatch
            pendingPatch.removeAll()
            sendPatchNow(queued)
        }
    }

    public func resetReady() {
        isReady = false
    }

    private func sendPatchNow(_ patch: [String: Any]) {
        guard let webView = webView else { return }
        let envelope: [String: Any] = [
            "v": 1,
            "surface": surface.rawValue,
            "patch": patch,
        ]
        let js = """
        if (window.persona && typeof window.persona.dispatch === 'function') {
            window.persona.dispatch(envelope);
        }
        """
        webView.callAsyncJavaScript(
            js,
            arguments: ["envelope": envelope],
            in: nil,
            in: .page,
            completionHandler: nil
        )
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = message.body
        let scheme = message.frameInfo.request.url?.scheme
        guard let intent = WebIntent.decode(
            body: body,
            scheme: scheme,
            surfaceFallback: self.surface
        ) else {
            return
        }
        if case .ready = intent {
            self.markReady()
        }
        self.onIntent?(intent)
    }
}

