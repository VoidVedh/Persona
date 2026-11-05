import Foundation
import WebKit

/// Breaks the `WKUserContentController -> WKScriptMessageHandler` strong retain cycle (§4.2, R-V2-6).
@MainActor
public final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    public weak var delegate: WKScriptMessageHandler?

    public init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

