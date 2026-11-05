import AppKit
import CryptoKit
import Foundation
import PersonaCore

/// Thread-safe cache mapping SHA-256 bundle-path hashes to 64x64 PNG data for `/icon/<id>.png`.
public final class IconCache {
    public static let shared = IconCache()

    private let lock = NSLock()
    private var pathById: [String: String] = [:]
    private let dataCache = NSCache<NSString, NSData>()

    public init() {
        dataCache.countLimit = 256
    }

    /// Registers an app bundle path and returns its 16-hex-char SHA-256 identifier.
    /// Never exposes a filesystem path in the identifier.
    public func register(bundlePath: String) -> String {
        let digest = SHA256.hash(data: Data(bundlePath.utf8))
        let id = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        lock.lock()
        pathById[id] = bundlePath
        lock.unlock()
        return id
    }

    public func registerPrecomputed(id: String, pngData: Data) {
        dataCache.setObject(pngData as NSData, forKey: id as NSString)
    }

    public func iconPNG(forId id: String) -> Data? {
        guard id.range(of: "^[0-9a-zA-Z_-]{2,64}$", options: .regularExpression) != nil else {
            return nil
        }
        if let cached = dataCache.object(forKey: id as NSString) {
            return cached as Data
        }
        lock.lock()
        let bundlePath = pathById[id]
        lock.unlock()

        guard let path = bundlePath, FileManager.default.fileExists(atPath: path) else {
            return Self.fallbackIconPNG()
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        guard let png = Self.renderPNG(image: icon, size: NSSize(width: 64, height: 64)) else {
            return Self.fallbackIconPNG()
        }
        dataCache.setObject(png as NSData, forKey: id as NSString)
        return png
    }

    private static func renderPNG(image: NSImage, size: NSSize) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    public static func fallbackIconPNG() -> Data {
        let size = NSSize(width: 64, height: 64)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor(calibratedRed: 0.0, green: 0.847, blue: 1.0, alpha: 1.0).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 8, dy: 8)).fill()
            return true
        }
        return renderPNG(image: img, size: size) ?? Data()
    }
}

/// Pure, deterministic router for `persona://app/...` URLs with strict path confinement (§4.4).
public final class WebUIRouter {
    public struct UserDirs: Equatable {
        public let wallpapers: URL?
        public let art: URL?

        public init(wallpapers: URL? = nil, art: URL? = nil) {
            self.wallpapers = wallpapers
            self.art = art
        }

        public static func standard() -> UserDirs {
            let support: URL
            if let env = ProcessInfo.processInfo.environment["PERSONA_SUPPORT_DIR"], !env.isEmpty {
                support = URL(fileURLWithPath: env, isDirectory: true)
            } else {
                let home = FileManager.default.homeDirectoryForCurrentUser
                support = home.appendingPathComponent("Library/Application Support/PersonaMode", isDirectory: true)
            }
            return UserDirs(
                wallpapers: support.appendingPathComponent("wallpapers", isDirectory: true),
                art: support.appendingPathComponent("art", isDirectory: true)
            )
        }
    }

    public struct Resolved: Equatable {
        public let data: Data
        public let mimeType: String
        public let headers: [String: String]
        public let sourceURL: URL?

        public init(data: Data, mimeType: String, headers: [String: String], sourceURL: URL? = nil) {
            self.data = data
            self.mimeType = mimeType
            self.headers = headers
            self.sourceURL = sourceURL
        }
    }

    public static let htmlCSP = "default-src 'self' persona: data: blob:; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' persona: data:; font-src 'self' persona: data:"

    public static let mimeTable: [String: String] = [
        "html": "text/html; charset=utf-8",
        "css": "text/css; charset=utf-8",
        "js": "application/javascript; charset=utf-8",
        "svg": "image/svg+xml",
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
        "heic": "image/heic",
        "ttf": "font/ttf",
        "json": "application/json; charset=utf-8",
    ]

    /// Resolves a URL path from `persona://app<path>` against the bundled `Resources` directory.
    /// Rejects path traversal (`..`, `%2e`, `\`, NUL, symlinks escaping root, sibling prefix directories).
    public static func resolve(
        path rawPath: String,
        resourcesRoot: URL,
        userDirs: UserDirs = .standard(),
        iconCache: IconCache = .shared
    ) -> Resolved? {
        guard !rawPath.isEmpty else { return nil }

        // Reject raw encoded or unencoded traversal characters immediately
        let lowerRaw = rawPath.lowercased()
        if lowerRaw.contains("..") ||
            lowerRaw.contains("%2e") ||
            lowerRaw.contains("%5c") ||
            lowerRaw.contains("%00") ||
            rawPath.contains("\\") ||
            rawPath.contains("\0") {
            return nil
        }

        guard let decoded = rawPath.removingPercentEncoding else { return nil }
        if decoded.contains("..") || decoded.contains("\\") || decoded.contains("\0") {
            return nil
        }

        // Normalize leading slash
        let cleanPath: String
        if decoded.hasPrefix("/") {
            cleanPath = String(decoded.dropFirst())
        } else {
            return nil
        }
        guard !cleanPath.isEmpty, !cleanPath.hasPrefix("/") else { return nil }

        // 1. Dynamic route: /wallpaper/current
        if cleanPath == "wallpaper/current" {
            return resolveWallpaper(resourcesRoot: resourcesRoot, userDirs: userDirs)
        }

        // 2. Dynamic route: /art/banner
        if cleanPath == "art/banner" {
            return resolveBanner(resourcesRoot: resourcesRoot, userDirs: userDirs)
        }

        // 3. Dynamic route: /icon/<id>.png
        if cleanPath.hasPrefix("icon/") && cleanPath.hasSuffix(".png") {
            let filePart = String(cleanPath.dropFirst("icon/".count))
            guard !filePart.contains("/") else { return nil }
            let id = String(filePart.dropLast(".png".count))
            guard let data = iconCache.iconPNG(forId: id), !data.isEmpty else { return nil }
            return Resolved(
                data: data,
                mimeType: "image/png",
                headers: ["Content-Type": "image/png", "Cache-Control": "no-store"]
            )
        }

        // 4. Static routes: `/fonts/*` from `<resources>/fonts/*`, all others from `<resources>/webui/*`
        let allowedRoot: URL
        let subPath: String
        if cleanPath.hasPrefix("fonts/") {
            allowedRoot = resourcesRoot.appendingPathComponent("fonts", isDirectory: true)
            subPath = String(cleanPath.dropFirst("fonts/".count))
        } else {
            allowedRoot = resourcesRoot.appendingPathComponent("webui", isDirectory: true)
            subPath = cleanPath
        }

        guard !subPath.isEmpty else { return nil }
        let candidate = allowedRoot.appendingPathComponent(subPath, isDirectory: false)
        return loadConfinedFile(candidate: candidate, allowedRoot: allowedRoot)
    }

    private static func resolveWallpaper(resourcesRoot: URL, userDirs: UserDirs) -> Resolved? {
        let validExts = ["png", "jpg", "jpeg", "heic", "webp"]
        if let userWallDir = userDirs.wallpapers,
           let items = try? FileManager.default.contentsOfDirectory(at: userWallDir, includingPropertiesForKeys: nil) {
            let sorted = items.sorted { $0.lastPathComponent < $1.lastPathComponent }
            for item in sorted {
                let ext = item.pathExtension.lowercased()
                if validExts.contains(ext),
                   let res = loadConfinedFile(candidate: item, allowedRoot: userWallDir) {
                    return res
                }
            }
        }

        let bundledDir = resourcesRoot.appendingPathComponent("wallpaper", isDirectory: true)
        let bundledPNG = bundledDir.appendingPathComponent("p3r_wallpaper.png")
        if let res = loadConfinedFile(candidate: bundledPNG, allowedRoot: bundledDir) {
            return res
        }

        // Fallback to SVG if PNG is not yet generated
        let webuiDir = resourcesRoot.appendingPathComponent("webui", isDirectory: true)
        let fallbackSVG = webuiDir.appendingPathComponent("svg/banner_default.svg")
        return loadConfinedFile(candidate: fallbackSVG, allowedRoot: webuiDir)
    }

    private static func resolveBanner(resourcesRoot: URL, userDirs: UserDirs) -> Resolved? {
        let validExts = ["svg", "png", "webp", "jpg", "jpeg"]
        if let userArtDir = userDirs.art {
            for ext in validExts {
                let candidate = userArtDir.appendingPathComponent("banner.\(ext)")
                if let res = loadConfinedFile(candidate: candidate, allowedRoot: userArtDir) {
                    return res
                }
            }
        }

        let webuiDir = resourcesRoot.appendingPathComponent("webui", isDirectory: true)
        let defaultBanner = webuiDir.appendingPathComponent("svg/banner_default.svg")
        return loadConfinedFile(candidate: defaultBanner, allowedRoot: webuiDir)
    }

    private static func loadConfinedFile(candidate: URL, allowedRoot: URL) -> Resolved? {
        let ext = candidate.pathExtension.lowercased()
        guard let mime = mimeTable[ext] else { return nil }

        let rootReal = allowedRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let candidateReal = candidate.standardizedFileURL.resolvingSymlinksInPath().path

        let rootPrefix = rootReal.hasSuffix("/") ? rootReal : (rootReal + "/")
        guard candidateReal.hasPrefix(rootPrefix) else {
            return nil
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidateReal, isDirectory: &isDir),
              !isDir.boolValue,
              let data = try? Data(contentsOf: URL(fileURLWithPath: candidateReal)) else {
            return nil
        }

        var headers: [String: String] = [
            "Content-Type": mime,
            "Cache-Control": "no-store",
        ]
        if ext == "html" {
            headers["Content-Security-Policy"] = htmlCSP
        }

        return Resolved(
            data: data,
            mimeType: mime,
            headers: headers,
            sourceURL: URL(fileURLWithPath: candidateReal)
        )
    }
}

