import Foundation
import PersonaCore

public enum RestoreSuite {
    public static func run(_ t: Harness) {
        t.suite("restore") {
            // Case 1: Order of calls recorded by FakeSystemAdapter is Dock, MenuBar, Wallpaper (I5)
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("restore_test_1_\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: tmpDir) }

                let initialWorld = FakeWorld(
                    dockAutohide: OriginalValue(present: true, value: false),
                    menuBarHide: OriginalValue(present: true, value: false),
                    menuBarFullscreen: OriginalValue(present: true, value: false),
                    scriptedDockAutohide: false,
                    scriptedMenuBarAutohide: false,
                    wallpapers: [
                        WallpaperSnapshot(displayUUID: "disp-1", name: "Screen", url: "file:///test.png", options: nil, isRestorable: true)
                    ]
                )
                let adapter = FakeSystemAdapter(world: initialWorld)
                let store = StateStore(supportDir: tmpDir)

                var lock: SessionLock?
                let state = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .system)
                let mutator = SystemMutator(store: store, adapter: adapter, state: state)

                try mutator.apply(.dockAutohide(true))
                try mutator.apply(.menuBarAutohide(true))

                adapter.calls.removeAll()

                let restoreService = RestoreService(store: store, adapter: adapter)
                let report = restoreService.restoreAll(reason: .userQuit)

                t.expect(report.verified, "restore verified successfully")

                let dockIdx = adapter.calls.firstIndex(where: { $0.hasPrefix("setDockAutohide") })
                let mbIdx = adapter.calls.firstIndex(where: { $0.hasPrefix("setMenuBarAutohide") })
                let wpIdx = adapter.calls.firstIndex(where: { $0.hasPrefix("setWallpapers") })

                t.expect(dockIdx != nil, "dock was restored")
                t.expect(mbIdx != nil, "menu bar was restored")
                t.expect(wpIdx != nil, "wallpaper was restored")

                if let d = dockIdx, let m = mbIdx, let w = wpIdx {
                    t.expect(d < m, "Dock (\(d)) restored before MenuBar (\(m)) (I5)")
                    t.expect(m < w, "MenuBar (\(m)) restored before Wallpaper (\(w)) (I5)")
                }
            } catch {
                t.fail("Case 1 error: \(error)")
            }

            // Case 2: Failure injected in Dock still restores Menu Bar
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("restore_test_2_\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: tmpDir) }

                let initialWorld = FakeWorld(
                    dockAutohide: OriginalValue(present: true, value: false),
                    menuBarHide: OriginalValue(present: true, value: false),
                    menuBarFullscreen: OriginalValue(present: true, value: false),
                    scriptedDockAutohide: false,
                    scriptedMenuBarAutohide: false,
                    wallpapers: []
                )
                let adapter = FakeSystemAdapter(world: initialWorld)
                let store = StateStore(supportDir: tmpDir)

                var lock: SessionLock?
                let state = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .overlay)
                let mutator = SystemMutator(store: store, adapter: adapter, state: state)

                try mutator.apply(.dockAutohide(true))
                try mutator.apply(.menuBarAutohide(true))

                adapter.calls.removeAll()
                // Inject failure in dock restoration
                adapter.failureInjections["setDockAutohide"] = SystemAdapterError.commandFailed("simulated dock failure")

                let restoreService = RestoreService(store: store, adapter: adapter)
                let report = restoreService.restoreAll(reason: .userQuit)

                let mbCalled = adapter.calls.contains(where: { $0.hasPrefix("setMenuBarAutohide") })
                t.expect(mbCalled, "MenuBar was restored despite Dock failure")

                let dockStep = report.steps.first(where: { $0.step == "dock" })
                let mbStep = report.steps.first(where: { $0.step == "menubar" })

                t.expectEqual(dockStep?.success, false, "dock step reported failure")
                t.expectEqual(mbStep?.success, true, "menubar step reported success")
            } catch {
                t.fail("Case 2 error: \(error)")
            }

            // Case 3: Double restore is a no-op
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("restore_test_3_\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: tmpDir) }

                let initialWorld = FakeWorld(
                    dockAutohide: OriginalValue(present: true, value: false),
                    menuBarHide: OriginalValue(present: true, value: false),
                    menuBarFullscreen: OriginalValue(present: true, value: false),
                    scriptedDockAutohide: false,
                    scriptedMenuBarAutohide: false,
                    wallpapers: []
                )
                let adapter = FakeSystemAdapter(world: initialWorld)
                let store = StateStore(supportDir: tmpDir)

                var lock: SessionLock?
                _ = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .overlay)

                let restoreService = RestoreService(store: store, adapter: adapter)
                let report1 = restoreService.restoreAll(reason: .userQuit)
                t.expect(report1.verified, "first restore verified")

                let report2 = restoreService.restoreAll(reason: .userQuit)
                t.expect(report2.verified, "second restore is safe and verified")
                t.expect(restoreService.hasRestored, "hasRestored is true")
            } catch {
                t.fail("Case 3 error: \(error)")
            }

            // Case 4: Verify mismatch keeps active=true and state file
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("restore_test_4_\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: tmpDir) }

                let initialWorld = FakeWorld(
                    dockAutohide: OriginalValue(present: true, value: false),
                    menuBarHide: OriginalValue(present: true, value: false),
                    menuBarFullscreen: OriginalValue(present: true, value: false),
                    scriptedDockAutohide: false,
                    scriptedMenuBarAutohide: false,
                    wallpapers: []
                )
                let adapter = FakeSystemAdapter(world: initialWorld)
                let store = StateStore(supportDir: tmpDir)

                var lock: SessionLock?
                let state = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .overlay)
                let mutator = SystemMutator(store: store, adapter: adapter, state: state)

                try mutator.apply(.dockAutohide(true))

                // Cause verify mismatch by injecting failure during restore of dock
                adapter.failureInjections["setDockAutohide"] = SystemAdapterError.commandFailed("simulated failure")

                let restoreService = RestoreService(store: store, adapter: adapter)
                let report = restoreService.restoreAll(reason: .userQuit)

                t.expectEqual(report.verified, false, "verify reports mismatch on failure")
                t.expect(store.stateFileExists, "state.json remains on disk when verify fails")

                let loaded = store.load()
                t.expectEqual(loaded?.active, true, "state remains active=true on verify mismatch")
                t.expectEqual(loaded?.phase, .degraded, "phase transitions to degraded")
            } catch {
                t.fail("Case 4 error: \(error)")
            }

            // Case 5: Successful restore leaves an empty support dir
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("restore_test_5_\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: tmpDir) }

                let initialWorld = FakeWorld(
                    dockAutohide: OriginalValue(present: true, value: false),
                    menuBarHide: OriginalValue(present: true, value: false),
                    menuBarFullscreen: OriginalValue(present: true, value: false),
                    scriptedDockAutohide: false,
                    scriptedMenuBarAutohide: false,
                    wallpapers: []
                )
                let adapter = FakeSystemAdapter(world: initialWorld)
                let store = StateStore(supportDir: tmpDir)

                var lock: SessionLock?
                let state = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .overlay)
                let mutator = SystemMutator(store: store, adapter: adapter, state: state)

                try mutator.apply(.dockAutohide(true))
                try mutator.apply(.menuBarAutohide(true))

                // Also touch heartbeat
                let heartbeatURL = tmpDir.appendingPathComponent("heartbeat")
                try? "12345".write(to: heartbeatURL, atomically: true, encoding: .utf8)

                let restoreService = RestoreService(store: store, adapter: adapter)
                let report = restoreService.restoreAll(reason: .userQuit)

                t.expect(report.verified, "restore verified")
                t.expect(!store.stateFileExists, "state.json deleted after verified restore")
                t.expect(!FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent("heartbeat").path), "heartbeat deleted")
                t.expect(!FileManager.default.fileExists(atPath: tmpDir.appendingPathComponent("session.lock").path), "session.lock deleted")
            } catch {
                t.fail("Case 5 error: \(error)")
            }
        }
    }
}
