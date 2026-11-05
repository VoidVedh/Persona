import AppKit
import Foundation
import PersonaCore

/// Scans, indexes, and searches macOS applications and Persona system actions.
public final class AppIndexer {
    public static let shared = AppIndexer()

    private let scanDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    private var cachedApps: [AppEntry] = []
    private var lastScanMtimes: [URL: Date] = [:]
    private let iconCache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "dev.persona.mode.indexer", qos: .utility)

    public init() {
        refreshIfNeeded()
    }

    public func refreshIfNeeded() {
        queue.sync {
            var needsScan = cachedApps.isEmpty
            for dir in scanDirectories {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: dir.path),
                   let mtime = attrs[.modificationDate] as? Date {
                    if lastScanMtimes[dir] != mtime {
                        needsScan = true
                        lastScanMtimes[dir] = mtime
                    }
                }
            }

            if needsScan {
                cachedApps = scanApplications()
            }
        }
    }

    public func search(query: String) -> [(item: LauncherItem, score: Int, matchedIndices: [Int])] {
        refreshIfNeeded()

        var allItems: [LauncherItem] = []
        // Built-in actions first
        for action in builtInActions() {
            allItems.append(.action(action))
        }
        // Indexed apps
        queue.sync {
            for app in cachedApps {
                allItems.append(.app(app))
            }
        }

        let ranked = FuzzyMatcher.rank(items: allItems, query: query) { item in
            item.name
        }

        // Apply +5 bonus for actions so quick commands rank easily
        var adjusted = ranked.map { entry -> (item: LauncherItem, score: Int, matchedIndices: [Int]) in
            let bonus = entry.item.isAction ? 5 : 0
            return (entry.item, entry.score + bonus, entry.matchedIndices)
        }

        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            adjusted.sort { $0.score > $1.score }
        }

        return adjusted
    }

    public func icon(for item: LauncherItem) -> NSImage? {
        switch item {
        case .action(let act):
            return NSImage(systemSymbolName: act.iconName, accessibilityDescription: act.name)
        case .app(let app):
            let key = app.id as NSString
            if let cached = iconCache.object(forKey: key) {
                return cached
            }
            let img = NSWorkspace.shared.icon(forFile: app.url.path)
            img.size = NSSize(width: 32, height: 32)
            iconCache.setObject(img, forKey: key)
            return img
        }
    }

    public var indexedAppCount: Int {
        refreshIfNeeded()
        return queue.sync { cachedApps.count } + builtInActions().count
    }

    public func builtInActions() -> [ActionEntry] {
        var actions: [ActionEntry] = [
            ActionEntry(id: "tile", name: "Tile Windows", detail: "Rearrange windows into dwindle grid", iconName: "rectangle.split.2x2", command: .tileNow),
            ActionEntry(id: "retile", name: "Retile", detail: "Re-apply active window tiling layout", iconName: "square.grid.2x2", command: .tileNow),
            ActionEntry(id: "toggleFloat", name: "Toggle Float", detail: "Float/unfloat focused window (⌃⌥F)", iconName: "arrow.up.and.down.and.arrow.left.and.right", command: .toggleFloatFocused),
            ActionEntry(id: "reloadTheme", name: "Reload Theme", detail: "Re-read config.json and refresh styles", iconName: "arrow.clockwise", command: .reloadTheme),
            ActionEntry(id: "toggleDarkHour", name: "Toggle Dark Hour", detail: "Force Dark Hour green aesthetic", iconName: "moon.fill", command: .toggleDarkHour),
            ActionEntry(id: "openTerminal", name: "Open Terminal (P3R)", detail: "Launch isolated terminal rice", iconName: "terminal", command: .openTerminal)
        ]

        let hasCava = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/cava") ||
                      FileManager.default.fileExists(atPath: "/usr/local/bin/cava")
        if hasCava {
            actions.append(
                ActionEntry(
                    id: "openVisualizer",
                    name: "Open Visualizer (cava)",
                    detail: "Audio spectrum visualizer",
                    iconName: "waveform",
                    command: .openTerminal
                )
            )
        }

        actions.append(
            ActionEntry(
                id: "exitPersona",
                name: "Exit Persona Mode",
                detail: "Cleanly restore stock macOS Desktop",
                iconName: "power",
                isDestructive: true,
                command: .exitPersona
            )
        )

        return actions
    }

    // MARK: - Scanning

    private func scanApplications() -> [AppEntry] {
        var entries: [AppEntry] = []
        var seenIDs: Set<String> = []
        let fm = FileManager.default

        for dir in scanDirectories {
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    enumerator.skipDescendants()

                    let bundle = Bundle(url: fileURL)
                    let info = bundle?.infoDictionary

                    // Skip background/helper agents
                    let isUIElement = info?["LSUIElement"] as? Bool ?? false
                    let isBackgroundOnly = info?["LSBackgroundOnly"] as? Bool ?? false
                    if (isUIElement || isBackgroundOnly) && !fileURL.path.hasPrefix("/System/Applications") {
                        continue
                    }

                    let name = (info?["CFBundleDisplayName"] as? String) ??
                               (info?["CFBundleName"] as? String) ??
                               fileURL.deletingPathExtension().lastPathComponent

                    let bundleId = bundle?.bundleIdentifier ?? fileURL.path

                    if !seenIDs.contains(fileURL.path) {
                        seenIDs.insert(fileURL.path)
                        entries.append(
                            AppEntry(
                                id: fileURL.path,
                                name: name,
                                bundleId: bundleId,
                                url: fileURL
                            )
                        )
                    }
                }
            }
        }

        entries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return entries
    }
}
