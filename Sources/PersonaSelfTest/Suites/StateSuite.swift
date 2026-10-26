import Foundation
import PersonaCore

public enum StateSuite {
    public static func run(_ t: Harness) {
        t.suite("state") {
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("state_test_\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: tmpDir) }

            let store = StateStore(supportDir: tmpDir)

            // 1. Snapshot with OriginalValue(present: false) survives
            let snapshot = SystemStateSnapshot(
                dock: DockSnapshot(autohide: OriginalValue<Bool>(present: false, value: nil)),
                menuBar: MenuBarSnapshot(
                    hideMenuBar: OriginalValue<Bool>(present: false, value: nil),
                    visibleInFullscreen: OriginalValue<Bool>(present: true, value: false),
                    scriptedAutohide: false,
                    mechanism: "systemEvents"
                ),
                wallpapers: [
                    WallpaperSnapshot(
                        displayUUID: "UUID-TEST-1",
                        name: "Retina Display",
                        url: "file:///System/Library/Desktop%20Pictures/Solid%20Colors/Black.png",
                        options: WallpaperOptions(imageScaling: 1, allowClipping: true, fillColorHex: "#000000"),
                        isRestorable: true
                    )
                ]
            )

            var ledger = RestoreLedger()
            let mId = ledger.append(.dockAutohide(true), status: .applied)

            let state = StateFile(
                schemaVersion: 1,
                sessionId: "TEST-SESSION-ID",
                active: true,
                appPid: 12345,
                createdAt: Date(),
                macOS: "26.6.2",
                wallpaperMode: .overlay,
                snapshot: snapshot,
                ledger: ledger,
                phase: .snapshotted
            )

            // 2. Round-trip save and load
            do {
                try store.save(state)
            } catch {
                t.fail("Failed to save state: \(error)")
            }

            // Check no .tmp file left
            let tmpPath = tmpDir.appendingPathComponent("state.json.tmp").path
            t.expect(!FileManager.default.fileExists(atPath: tmpPath), "no state.json.tmp left after save")

            // Check file permissions 0600
            let statePath = tmpDir.appendingPathComponent("state.json").path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: statePath),
               let perms = attrs[.posixPermissions] as? NSNumber {
                t.expectEqual(perms.intValue, 0o600, "state.json has 0600 permissions")
            } else {
                t.fail("Could not read permissions for state.json")
            }

            let loaded = store.load()
            t.expect(loaded != nil, "loaded state is non-nil")
            if let l = loaded {
                t.expectEqual(l.sessionId, "TEST-SESSION-ID", "sessionId matches")
                t.expectEqual(l.snapshot.dock.autohide.present, false, "dock.autohide.present == false survives")
                t.expectEqual(l.snapshot.dock.autohide.value, nil, "dock.autohide.value == nil survives")
                t.expectEqual(l.snapshot.menuBar.visibleInFullscreen.present, true, "menuBar.visibleInFullscreen.present == true")
                t.expectEqual(l.snapshot.menuBar.visibleInFullscreen.value, false, "menuBar.visibleInFullscreen.value == false")
                t.expectEqual(l.snapshot.wallpapers.count, 1, "wallpaper count matches")
                t.expectEqual(l.ledger.entries.count, 1, "ledger entries count matches")
                t.expectEqual(l.ledger.entries.first?.id, mId, "ledger entry ID matches")
            }

            // 3. Fallback to state.json.prev when state.json is corrupted
            var secondState = state
            secondState.sessionId = "SECOND-SESSION-ID"
            try? store.save(secondState)

            // Verify .prev was created
            let prevPath = tmpDir.appendingPathComponent("state.json.prev").path
            t.expect(FileManager.default.fileExists(atPath: prevPath), "state.json.prev exists after second save")

            // Corrupt primary state.json
            try? "{ incomplete corrupted json ...".write(toFile: statePath, atomically: true, encoding: .utf8)
            let fallbackLoaded = store.load()
            t.expect(fallbackLoaded != nil, "fallback loaded state is non-nil when state.json is corrupt")
            t.expectEqual(fallbackLoaded?.sessionId, "TEST-SESSION-ID", "fallback loaded previous generation")

            // 4. SessionLock tests
            guard let lock1 = SessionLock(dir: tmpDir) else {
                t.fail("first SessionLock acquisition failed")
                return
            }
            t.pass("first SessionLock acquired")

            let lock2 = SessionLock(dir: tmpDir)
            t.expect(lock2 == nil, "second SessionLock acquisition fails while lock1 is held")

            let isHeld = SessionLock.isHeldByOther(dir: tmpDir)
            t.expect(isHeld, "isHeldByOther returns true when locked")

            lock1.release()
            t.expect(!SessionLock.isHeldByOther(dir: tmpDir), "isHeldByOther returns false after release")

            let lock3 = SessionLock(dir: tmpDir)
            t.expect(lock3 != nil, "SessionLock can be re-acquired after release")
            lock3?.release()
        }
    }
}
