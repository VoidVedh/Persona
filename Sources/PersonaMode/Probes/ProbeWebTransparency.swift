import AppKit
import Foundation
import PersonaCore
import PersonaKit
import WebKit

/// Spike S-V2-1 probe: empirically verifies transparent `WKWebView` rendering on this macOS build.
@MainActor
public enum ProbeWebTransparency: Probe {
    public static func run(args: [String]) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let width: CGFloat = 200
        let height: CGFloat = 200

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: cfg)
        webView.setValue(false, forKey: "drawsBackground")
        var underPage = false
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
            underPage = (webView.underPageBackgroundColor == .clear)
        }
        let kvc = (webView.value(forKey: "drawsBackground") as? Bool) == false

        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.alphaValue = 0.02
        win.contentView = webView
        win.orderFrontRegardless()

        let html = """
        <!doctype html>
        <html>
        <head>
        <style>
          html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
          .box { position: absolute; left: 50px; top: 50px; width: 100px; height: 100px; background: rgba(0, 216, 255, 0.85); }
        </style>
        </head>
        <body data-ready="1"><div class="box"></div></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)

        let deadline = Date().addingTimeInterval(5.0)
        var ready = false
        while Date() < deadline && !ready {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            webView.evaluateJavaScript("document.body && document.body.dataset.ready === '1'") { val, _ in
                if (val as? Bool) == true {
                    ready = true
                }
            }
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))

        var snapImage: NSImage?
        var snapDone = false
        let snapCfg = WKSnapshotConfiguration()
        snapCfg.rect = CGRect(x: 0, y: 0, width: width, height: height)
        snapCfg.snapshotWidth = NSNumber(value: Int(width))
        webView.takeSnapshot(with: snapCfg) { img, _ in
            snapImage = img
            snapDone = true
        }
        let snapDeadline = Date().addingTimeInterval(4.0)
        while Date() < snapDeadline && !snapDone {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        win.orderOut(nil)
        win.contentView = nil
        win.close()
        WebCacheCleaner.cleanup()

        var cornerAlpha: Double = 1.0
        if let img = snapImage,
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let color = rep.colorAt(x: 4, y: 4)?.usingColorSpace(.deviceRGB) {
            cornerAlpha = Double(color.alphaComponent)
        }

        let result: [String: Any] = [
            "alphaAtCorner": (cornerAlpha * 1000).rounded() / 1000,
            "chosen": "drawsBackground=false + underPageBackgroundColor=.clear + nonOpaqueNSWindow",
            "drawsBackgroundKVC": kvc,
            "underPage": underPage,
        ]
        return ProbeIO.emit(result, args: args)
    }
}
