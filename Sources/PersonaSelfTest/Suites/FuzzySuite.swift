import AppKit
import Carbon
import Foundation
import PersonaCore
import PersonaKit

public enum FuzzySuite {
    public static func run(_ t: Harness) {
        t.suite("fuzzy") {
            // 1. Basic subsequence matching
            let match1 = FuzzyMatcher.score(query: "saf", candidate: "Safari")
            t.expect(match1 != nil, "saf matches Safari")
            if let m = match1 {
                t.expectEqual(m.matchedIndices, [0, 1, 2], "saf matches indices 0, 1, 2 in Safari")
                t.expect(m.score > 40, "saf in Safari receives high score")
            }

            // 2. Word boundary match
            let match2 = FuzzyMatcher.score(query: "vsc", candidate: "Visual Studio Code")
            t.expect(match2 != nil, "vsc matches Visual Studio Code")
            if let m = match2 {
                t.expectEqual(m.matchedIndices, [0, 7, 14], "vsc matches initials V, S, C")
            }

            // 3. CamelCase match
            let match3 = FuzzyMatcher.score(query: "ka", candidate: "keychainAccess")
            t.expect(match3 != nil, "ka matches keychainAccess")

            // 4. Non-matching query
            let matchNone = FuzzyMatcher.score(query: "xyz", candidate: "Safari")
            t.expect(matchNone == nil, "xyz does not match Safari")

            // 5. Ranking order: saf query
            let apps = ["System Settings", "Safari", "Keychain Access", "Notes"]
            let ranked = FuzzyMatcher.rank(items: apps, query: "saf") { $0 }
            t.expect(ranked.count >= 1, "at least 1 match for saf")
            if let first = ranked.first {
                t.expectEqual(first.item, "Safari", "Safari ranks first for query 'saf'")
            }

            // 6. Ranking order: term query
            let termApps = ["Font Book", "Terminal", "Activity Monitor", "System Settings"]
            let rankedTerm = FuzzyMatcher.rank(items: termApps, query: "term") { $0 }
            if let first = rankedTerm.first {
                t.expectEqual(first.item, "Terminal", "Terminal ranks first for 'term'")
            }

            // 7. Empty query returns all items in original order
            let emptyRanked = FuzzyMatcher.rank(items: apps, query: "") { $0 }
            t.expectEqual(emptyRanked.count, apps.count, "empty query preserves all items")
            t.expectEqual(emptyRanked.map { $0.item }, apps, "empty query preserves original order")

            // 8. Built-in quick commands & AppIndexer
            let actions = AppIndexer.shared.builtInActions().map(\.name)
            t.expect(actions.contains("Tile Windows"), "builtInActions includes 'Tile Windows'")
            t.expect(actions.contains("Retile"), "builtInActions includes 'Retile'")
            t.expect(actions.contains("Exit Persona Mode"), "builtInActions includes 'Exit Persona Mode'")
            t.expect(AppIndexer.shared.indexedAppCount > 10, "AppIndexer indexes > 10 apps + actions")

            let exitResults = AppIndexer.shared.search(query: "exit")
            t.expectEqual(exitResults.first?.item.name, "Exit Persona Mode", "'exit' query ranks 'Exit Persona Mode' first")

            // 9. HotKeyCenter chord parsing & registration
            let hk = HotKeyCenter.shared
            let optSpace = hk.parseChord("opt+space")
            t.expect(optSpace != nil, "parses opt+space")
            t.expectEqual(optSpace?.keyCode, 0x31, "space keyCode == 0x31")
            t.expectEqual(optSpace?.modifiers, UInt32(optionKey), "opt modifier == optionKey")

            let panicChord = hk.parseChord("ctrl+opt+cmd+q")
            t.expect(panicChord != nil, "parses ctrl+opt+cmd+q")
            t.expectEqual(panicChord?.keyCode, 0x0C, "q keyCode == 0x0C")
            t.expectEqual(
                panicChord?.modifiers,
                UInt32(controlKey | optionKey | cmdKey),
                "ctrl+opt+cmd modifiers combined"
            )

            let arrowUp = hk.parseChord("up")
            t.expectEqual(arrowUp?.keyCode, 0x7E, "up arrow keyCode == 0x7E")

            let statuses = hk.registerAll(config: AppConfig())
            t.expect(!statuses.isEmpty, "registerAll returns chord statuses")
            t.expect(hk.registeredCount > 0, "at least 1 hotkey registered")
            hk.unregisterAll()
            t.expectEqual(hk.registeredCount, 0, "unregisterAll clears all hotkeys")

            // 10. Launcher state machine (panel configuration, keyboard navigation, Enter execution, Esc & focus-loss dismissal)
            MainActor.assumeIsolated {
                runLauncherStateMachineTests(t)
            }
        }
    }

    @MainActor
    private static func runLauncherStateMachineTests(_ t: Harness) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let controller = LauncherController.shared
        var executedItem: LauncherItem?
        controller.onCustomExecute = { item, _ in
            executedItem = item
        }
        defer {
            controller.onCustomExecute = nil
            controller.stop()
        }

        // Open launcher
        controller.show()
        t.expect(controller.isVisible, "launcher isVisible == true after show()")
        t.expectEqual(controller.panel?.level.rawValue, WindowLevels.launcher.rawValue, "launcher level == 100")
        t.expect(controller.panel?.canBecomeKey == true, "launcher panel canBecomeKey == true")
        t.expectEqual(controller.viewModel.query, "", "query reset to empty on show()")
        t.expect(!controller.viewModel.matches.isEmpty, "initial matches populated")

        // Type 'exit' via keyboard handler
        controller.handleKeyCode(0, characters: "e")
        controller.handleKeyCode(0, characters: "x")
        controller.handleKeyCode(0, characters: "i")
        controller.handleKeyCode(0, characters: "t")
        t.expectEqual(controller.viewModel.query, "exit", "typing updates query to 'exit'")
        t.expectEqual(controller.viewModel.selectedMatch?.item.name, "Exit Persona Mode", "'exit' selects Exit Persona Mode")

        // Backspace removes last character
        controller.handleKeyCode(51)
        t.expectEqual(controller.viewModel.query, "exi", "Backspace removes last character")

        // Cmd+Backspace clears query
        controller.handleKeyCode(51, modifiers: [.command])
        t.expectEqual(controller.viewModel.query, "", "Cmd+Backspace clears query")

        // Down / Up keyboard navigation
        t.expectEqual(controller.viewModel.selectedIndex, 0, "initial selectedIndex == 0")
        controller.handleKeyCode(125) // Down arrow
        t.expectEqual(controller.viewModel.selectedIndex, 1, "Down arrow advances selectedIndex to 1")
        controller.handleKeyCode(126) // Up arrow
        t.expectEqual(controller.viewModel.selectedIndex, 0, "Up arrow returns selectedIndex to 0")

        // Enter executes selected item and dismisses launcher
        controller.handleKeyCode(0, characters: "retile")
        t.expectEqual(controller.viewModel.selectedMatch?.item.name, "Retile", "'retile' selects Retile quick command")
        controller.handleKeyCode(36) // Return
        t.expect(!controller.isVisible, "Enter dismisses launcher")
        t.expectEqual(executedItem?.name, "Retile", "Enter executed 'Retile' item")

        // Re-open and test Esc dismissal
        controller.show()
        t.expect(controller.isVisible, "launcher visible after second show()")
        controller.handleKeyCode(53) // Esc
        t.expect(!controller.isVisible, "Esc dismisses launcher")

        // Re-open and test focus-loss (didResignKey) dismissal
        controller.show()
        t.expect(controller.isVisible, "launcher visible before focus loss")
        if let panel = controller.panel {
            NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: panel)
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        t.expect(!controller.isVisible, "focus loss (didResignKeyNotification) dismisses launcher")
    }
}
