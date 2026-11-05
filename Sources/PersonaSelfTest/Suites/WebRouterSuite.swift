import Foundation
import PersonaCore
import PersonaKit

public enum WebRouterSuite {
    public static func run(_ t: Harness) {
        t.suite("webrouter") {
            let tempBase = FileManager.default.temporaryDirectory
                .appendingPathComponent("persona-webrouter-test-\(UUID().uuidString)", isDirectory: true)
            let root = tempBase.appendingPathComponent("Resources", isDirectory: true)
            let webui = root.appendingPathComponent("webui", isDirectory: true)
            let evilSibling = root.appendingPathComponent("webui-evil", isDirectory: true)
            let fonts = root.appendingPathComponent("fonts", isDirectory: true)
            let userArt = tempBase.appendingPathComponent("user-art", isDirectory: true)
            let userWall = tempBase.appendingPathComponent("user-wall", isDirectory: true)

            try? FileManager.default.createDirectory(at: webui.appendingPathComponent("svg"), withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: evilSibling, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: fonts, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: userArt, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: userWall, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempBase) }

            try? "<!doctype html><title>topbar</title>".write(
                to: webui.appendingPathComponent("topbar.html"),
                atomically: true,
                encoding: .utf8
            )
            try? "<svg>default-banner</svg>".write(
                to: webui.appendingPathComponent("svg/banner_default.svg"),
                atomically: true,
                encoding: .utf8
            )
            try? "SECRET".write(
                to: evilSibling.appendingPathComponent("secret.html"),
                atomically: true,
                encoding: .utf8
            )
            try? "FONT_BYTES".write(
                to: fonts.appendingPathComponent("BebasNeue-Regular.ttf"),
                atomically: true,
                encoding: .utf8
            )
            try? "EXE_BYTES".write(
                to: webui.appendingPathComponent("bad.exe"),
                atomically: true,
                encoding: .utf8
            )

            // Symlink inside webui pointing outside webui
            let outsideSecret = tempBase.appendingPathComponent("outside.html")
            try? "OUTSIDE".write(to: outsideSecret, atomically: true, encoding: .utf8)
            try? FileManager.default.createSymbolicLink(
                at: webui.appendingPathComponent("escape.html"),
                withDestinationURL: outsideSecret
            )

            let emptyDirs = WebUIRouter.UserDirs(wallpapers: nil, art: nil)

            // 1. Valid HTML route + MIME + CSP header
            let topbarRes = WebUIRouter.resolve(path: "/topbar.html", resourcesRoot: root, userDirs: emptyDirs)
            t.expect(topbarRes != nil, "resolves /topbar.html")
            t.expectEqual(topbarRes?.mimeType, "text/html; charset=utf-8", "HTML MIME type")
            t.expect(topbarRes?.headers["Content-Security-Policy"] != nil, "HTML includes CSP header")

            // 2. Valid font route
            let fontRes = WebUIRouter.resolve(path: "/fonts/BebasNeue-Regular.ttf", resourcesRoot: root, userDirs: emptyDirs)
            t.expect(fontRes != nil, "resolves /fonts/BebasNeue-Regular.ttf")
            t.expectEqual(fontRes?.mimeType, "font/ttf", "TTF MIME type")

            // 3. Path traversal rejections
            let attacks = [
                "/../outside.html",
                "/../../etc/passwd",
                "/%2e%2e/outside.html",
                "/%2E%2E/outside.html",
                "/..\\outside.html",
                "/topbar.html%00.png",
                "//topbar.html",
                "topbar.html",
                "/../webui-evil/secret.html",
                "/escape.html",
            ]
            for attack in attacks {
                let r = WebUIRouter.resolve(path: attack, resourcesRoot: root, userDirs: emptyDirs)
                t.expect(r == nil, "rejects traversal/invalid path '\(attack)'")
            }

            // 4. Unknown extension -> nil (404)
            let badExt = WebUIRouter.resolve(path: "/bad.exe", resourcesRoot: root, userDirs: emptyDirs)
            t.expect(badExt == nil, "rejects unknown extension .exe")

            // 5. Default vs user override for /art/banner
            let defBanner = WebUIRouter.resolve(path: "/art/banner", resourcesRoot: root, userDirs: emptyDirs)
            t.expectEqual(
                String(data: defBanner?.data ?? Data(), encoding: .utf8),
                "<svg>default-banner</svg>",
                "serves bundled default banner when user art dir is empty"
            )

            try? "<svg>user-custom-banner</svg>".write(
                to: userArt.appendingPathComponent("banner.svg"),
                atomically: true,
                encoding: .utf8
            )
            let customDirs = WebUIRouter.UserDirs(wallpapers: userWall, art: userArt)
            let userBanner = WebUIRouter.resolve(path: "/art/banner", resourcesRoot: root, userDirs: customDirs)
            t.expectEqual(
                String(data: userBanner?.data ?? Data(), encoding: .utf8),
                "<svg>user-custom-banner</svg>",
                "user art overrides default banner"
            )

            // 6. Icon route never exposes filesystem path
            let cache = IconCache()
            let iconId = cache.register(bundlePath: "/Applications/Safari.app")
            t.expect(!iconId.contains("/"), "iconId never contains slash")
            t.expect(!iconId.lowercased().contains("safari"), "iconId is a hash, not a path")
            let iconRes = WebUIRouter.resolve(
                path: "/icon/\(iconId).png",
                resourcesRoot: root,
                userDirs: emptyDirs,
                iconCache: cache
            )
            t.expect(iconRes != nil, "resolves /icon/<id>.png")
            t.expectEqual(iconRes?.mimeType, "image/png", "icon route serves image/png")
        }
    }
}

