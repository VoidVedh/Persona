import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PersonaCore
import PersonaKit
import WebKit

/// Deterministic off-screen WebKit renderer for `--probe render webui <surface> <out.png>`
/// and `--probe render composite <out.png>` (§12.1, S-V2-2).
@MainActor
public enum ProbeRenderWebUI {
    public static func run(args: [String]) -> Int32 {
        guard args.count >= 2 else {
            fputs("Usage: --probe render webui <topbar|hud|launcher|wallpaper|shapes> <out.png> [--fixture name] [--w W] [--h H] [--scale S] [--freeze ms] [--seed n] [--phase darkHour]\n", stderr)
            return 1
        }

        let surfaceRaw = args[0]
        let outPath = args[1]

        let defaultW: Double
        let defaultH: Double
        switch surfaceRaw {
        case "topbar":
            defaultW = 1512; defaultH = 44
        case "launcher":
            defaultW = 980; defaultH = 560
        case "shapes":
            defaultW = 900; defaultH = 520
        default:
            defaultW = 1512; defaultH = 982
        }

        let width = CGFloat(ProbeIO.double(of: "--w", in: args, default: defaultW))
        let height = CGFloat(ProbeIO.double(of: "--h", in: args, default: defaultH))
        let scale = CGFloat(ProbeIO.double(of: "--scale", in: args, default: 2.0))
        let freezeMs = ProbeIO.int(of: "--freeze", in: args, default: 1000)
        let seed = ProbeIO.int(of: "--seed", in: args, default: 7)
        let fixture = ProbeIO.string(of: "--fixture", in: args)
        let phase = ProbeIO.string(of: "--phase", in: args)
        let query = ProbeIO.string(of: "--query", in: args)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "freeze", value: "\(freezeMs)"),
            URLQueryItem(name: "seed", value: "\(seed)"),
        ]
        if let fixture = fixture {
            queryItems.append(URLQueryItem(name: "fixture", value: fixture))
        }
        if let phase = phase {
            queryItems.append(URLQueryItem(name: "phase", value: phase))
        }
        if let query = query {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        guard let cgImage = snapshotWebPage(
            pageName: (surfaceRaw == "shapes") ? "dev-shapes" : surfaceRaw,
            width: width,
            height: height,
            scale: scale,
            queryItems: queryItems
        ) else {
            fputs("Error: failed to capture snapshot for webui surface '\(surfaceRaw)'\n", stderr)
            return 1
        }

        guard writePNG(cgImage: cgImage, to: outPath) else {
            fputs("Error: failed to write PNG to \(outPath)\n", stderr)
            return 1
        }

        print("Rendered webui/\(surfaceRaw) to \(outPath) (\(cgImage.width)x\(cgImage.height) px)")
        return 0
    }

    public static func runComposite(args: [String]) -> Int32 {
        guard let outPath = args.first else {
            fputs("Usage: --probe render composite <out.png> [--w 1512 --h 982]\n", stderr)
            return 1
        }
        let width = CGFloat(ProbeIO.double(of: "--w", in: args, default: 1512))
        let height = CGFloat(ProbeIO.double(of: "--h", in: args, default: 982))
        let scale = CGFloat(ProbeIO.double(of: "--scale", in: args, default: 1.0))

        let hudItems = [
            URLQueryItem(name: "fixture", value: "hud.afterschool"),
            URLQueryItem(name: "freeze", value: "1500"),
            URLQueryItem(name: "seed", value: "7"),
        ]
        let barItems = [
            URLQueryItem(name: "fixture", value: "bar.default"),
            URLQueryItem(name: "freeze", value: "1200"),
            URLQueryItem(name: "seed", value: "7"),
        ]

        let barMarginSide: CGFloat = 10
        let barMarginTop: CGFloat = 6
        let barH: CGFloat = 44
        let barW = width - barMarginSide * 2

        guard let hudCG = snapshotWebPage(pageName: "hud", width: width, height: height, scale: scale, queryItems: hudItems),
              let barCG = snapshotWebPage(pageName: "topbar", width: barW, height: barH, scale: scale, queryItems: barItems) else {
            fputs("Error: failed to snapshot HUD or TopBar for composite\n", stderr)
            return 1
        }

        let pxW = Int(width * scale)
        let pxH = Int(height * scale)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: pxW,
                  height: pxH,
                  bitsPerComponent: 8,
                  bytesPerRow: pxW * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            return 1
        }

        // CoreGraphics origin is bottom-left:
        ctx.draw(hudCG, in: CGRect(x: 0, y: 0, width: CGFloat(pxW), height: CGFloat(pxH)))
        let barRect = CGRect(
            x: barMarginSide * scale,
            y: (height - barMarginTop - barH) * scale,
            width: barW * scale,
            height: barH * scale
        )
        ctx.draw(barCG, in: barRect)

        guard let outCG = ctx.makeImage(), writePNG(cgImage: outCG, to: outPath) else {
            fputs("Error: failed to finalize composite PNG at \(outPath)\n", stderr)
            return 1
        }

        print("Rendered composite to \(outPath) (\(pxW)x\(pxH) px)")
        return 0
    }

    public static func snapshotWebPage(
        pageName: String,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat,
        queryItems: [URLQueryItem]
    ) -> CGImage? {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Fonts.register()

        let surface = WebSurface(rawValue: pageName) ?? .topbar
        let web = WebSurfaceView(surface: surface, interactive: false, debug: false)
        web.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let win = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = .floating
        win.alphaValue = 0.02
        win.contentView = web
        win.orderFrontRegardless()

        var comps = URLComponents()
        comps.scheme = "persona"
        comps.host = "app"
        comps.path = "/\(pageName).html"
        if !queryItems.isEmpty {
            comps.queryItems = queryItems
        }
        guard let url = comps.url else {
            web.teardown()
            win.close()
            return nil
        }

        web.load(URLRequest(url: url))

        let deadline = Date().addingTimeInterval(8.0)
        var isReady = false
        while Date() < deadline && !isReady {
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
            web.evaluateJavaScript("document.documentElement.dataset.ready === '1'") { val, _ in
                if (val as? Bool) == true {
                    isReady = true
                }
            }
        }

        if !isReady {
            fputs("Warning: timed out waiting for data-ready on \(url.absoluteString)\n", stderr)
            web.teardown()
            win.orderOut(nil)
            win.close()
            return nil
        }

        // Allow 2 display frames for WebKit compositor flush
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        var capturedImage: NSImage?
        var snapDone = false
        let snapConfig = WKSnapshotConfiguration()
        snapConfig.rect = CGRect(x: 0, y: 0, width: width, height: height)
        let hostBacking = max(1.0, win.backingScaleFactor)
        snapConfig.snapshotWidth = NSNumber(value: Double(width * scale) / Double(hostBacking))

        web.takeSnapshot(with: snapConfig) { img, err in
            if let err = err {
                fputs("takeSnapshot error: \(err.localizedDescription)\n", stderr)
            }
            capturedImage = img
            snapDone = true
        }

        let snapDeadline = Date().addingTimeInterval(5.0)
        while Date() < snapDeadline && !snapDone {
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        }

        web.teardown()
        win.orderOut(nil)
        win.contentView = nil
        win.close()
        WebCacheCleaner.cleanup()

        guard let nsImage = capturedImage else { return nil }
        var rect = NSRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    public static func writePNG(cgImage: CGImage, to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        return CGImageDestinationFinalize(dest)
    }
}
