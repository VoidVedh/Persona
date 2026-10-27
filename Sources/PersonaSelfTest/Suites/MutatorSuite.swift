import Foundation
import PersonaCore

public enum MutatorSuite {
    public static func run(_ t: Harness) {
        t.suite("mutator") {
            // Case 1: apply -> restore returns world to original
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mutator_test_1_\(UUID().uuidString)", isDirectory: true)
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

                t.expectEqual(adapter.world.dockAutohide.value, true, "dock mutated to true")
                t.expectEqual(adapter.world.scriptedMenuBarAutohide, true, "menu bar mutated to true")

                lock?.release()
                lock = nil

                try RecoveryManager.recover(store: store, adapter: adapter)

                t.expectEqual(adapter.world, initialWorld, "world restored to original")
                t.expectEqual(store.load()?.active ?? false, false, "state is no longer active after clean restore")
            } catch {
                t.fail("Case 1 error: \(error)")
            }

            // Case 2: Crash injection across all steps of apply sequence
            do {
                for k in 0...7 {
                    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mutator_crash_\(k)_\(UUID().uuidString)", isDirectory: true)
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

                    if k >= 1 {
                        let state = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .overlay)
                        var curState = state

                        if k >= 2 {
                            let id1 = curState.ledger.append(.dockAutohide(true), status: .pending)
                            try store.save(curState)

                            if k >= 3 {
                                try adapter.setDockAutohide(true)

                                if k >= 4 {
                                    curState.ledger.markApplied(id1)
                                    try store.save(curState)

                                    if k >= 5 {
                                        let id2 = curState.ledger.append(.menuBarAutohide(true), status: .pending)
                                        try store.save(curState)

                                        if k >= 6 {
                                            try adapter.setMenuBarAutohide(true)

                                            if k >= 7 {
                                                curState.ledger.markApplied(id2)
                                                try store.save(curState)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Simulate crash: release lock & drop in-memory objects
                    lock?.release()
                    lock = nil

                    // Run RecoveryManager against store + current adapter
                    _ = try RecoveryManager.recoverIfStale(store: store, adapter: adapter)

                    t.expectEqual(adapter.world, initialWorld, "crash injection step \(k): world equals initialWorld")
                }
            } catch {
                t.fail("Case 2 error: \(error)")
            }

            // Case 3: pending-only ledger entries are restored
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mutator_test_3_\(UUID().uuidString)", isDirectory: true)
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
                var state = try SnapshotService.begin(store: store, lock: &lock, adapter: adapter, mode: .overlay)

                // Mutation is pending-only in ledger, but adapter was modified
                _ = state.ledger.append(.dockAutohide(true), status: .pending)
                try store.save(state)
                try adapter.setDockAutohide(true)

                t.expectEqual(adapter.world.dockAutohide.value, true, "dock is true before recovery")

                lock?.release()
                lock = nil

                try RecoveryManager.recover(store: store, adapter: adapter)
                t.expectEqual(adapter.world.dockAutohide.value, false, "pending-only mutation restored to original false")
            } catch {
                t.fail("Case 3 error: \(error)")
            }

            // Case 4: stale-active at launch recovers before snapshot (second snapshot never equals mutated world)
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mutator_test_4_\(UUID().uuidString)", isDirectory: true)
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

                var lock1: SessionLock?
                let state1 = try SnapshotService.begin(store: store, lock: &lock1, adapter: adapter, mode: .overlay)
                let mutator = SystemMutator(store: store, adapter: adapter, state: state1)
                try mutator.apply(.dockAutohide(true))

                t.expectEqual(adapter.world.dockAutohide.value, true, "mutated world has dock=true")

                // Simulate crash: release lock but leave state.json active=true on disk
                lock1?.release()
                lock1 = nil

                // Second session starts: SnapshotService.begin
                var lock2: SessionLock?
                let state2 = try SnapshotService.begin(store: store, lock: &lock2, adapter: adapter, mode: .overlay)

                // Stale state must have been recovered BEFORE taking second snapshot
                t.expectEqual(state2.snapshot.dock.autohide.value, false, "second snapshot captured pristine dock=false, not mutated true")
                t.expectEqual(adapter.world.dockAutohide.value, false, "world is pristine after stale recovery")

                lock2?.release()
                lock2 = nil
                try RecoveryManager.recover(store: store, adapter: adapter)
            } catch {
                t.fail("Case 4 error: \(error)")
            }

            // Case 5: absent-key originals restore to 'absent'
            do {
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mutator_test_5_\(UUID().uuidString)", isDirectory: true)
                defer { try? FileManager.default.removeItem(at: tmpDir) }

                let initialWorld = FakeWorld(
                    dockAutohide: OriginalValue(present: false, value: nil),
                    menuBarHide: OriginalValue(present: false, value: nil),
                    menuBarFullscreen: OriginalValue(present: false, value: nil),
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

                t.expectEqual(adapter.world.dockAutohide.present, true, "dock present=true while mutated")
                t.expectEqual(adapter.world.dockAutohide.value, true, "dock value=true while mutated")

                lock?.release()
                lock = nil

                try RecoveryManager.recover(store: store, adapter: adapter)

                t.expectEqual(adapter.world.dockAutohide.present, false, "dock present restored to false (absent)")
                t.expectEqual(adapter.world.dockAutohide.value, nil, "dock value restored to nil")
                t.expectEqual(adapter.world.menuBarHide.present, false, "menu bar present restored to false (absent)")
                t.expectEqual(adapter.world.menuBarHide.value, nil, "menu bar value restored to nil")
            } catch {
                t.fail("Case 5 error: \(error)")
            }
        }
    }
}
