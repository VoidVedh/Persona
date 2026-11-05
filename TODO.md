# Persona Mode — Engineering TODO (for the executing agent)

> Companion to [`ARCHITECTURE.md`](./ARCHITECTURE.md). **Read it fully before starting.** Section references like `§9.6` point there.
> Execute **top to bottom**. Do **not** start a phase until the previous phase's *Phase Gate* is fully green.

---

## 0. Ground Rules (read first, apply always)

### 0.1 Safety rules (this app hides the user's Dock/Menu Bar — be careful)
1. **Until task P1.11 passes, never run anything that performs real Dock/Menu Bar mutation** except inside explicitly marked spike tasks. Everything else runs with `PERSONA_DRY_RUN=1`.
2. Always use a throwaway state directory in tests: `export PERSONA_SUPPORT_DIR="$(mktemp -d)"`. Never let tests touch `~/Library/Application Support/PersonaMode`.
3. Before any task that says **⚠ REAL MUTATION**, run `make restore` once to prove the panic script works, and chain the restore into the same command line (`…; sleep N; restore`) so a hung session self-heals.
4. If the Dock or Menu Bar ends up hidden at any time: run `scripts/restore_macos.sh --force-defaults`.
5. Never delete paths derived from JSON unless they pass the prefix guard (§9.5).
6. Do not add dependencies (SwiftPM packages, brew installs, pip). Everything is system Swift + `/usr/bin` tools. (Optional extras: `fastfetch`, terminals — detected, never required.)

### 0.2 Environment facts (probed; see §2)
- macOS 26.6.2 arm64, Swift 6.4, **Command Line Tools only (no Xcode)**, notched display.
- `swift test` is **not usable**. Tests = `swift run persona-selftest [suite…]`; runtime checks = `--probe`.
- `defaults read` of `_HIHideMenuBar`, `AppleMenuBarVisibleInFullscreen`, `com.apple.dock autohide` currently reports *"does not exist"* → absent-key handling is mandatory.
- SwiftPM output path is non-standard → use `swift build --show-bin-path`.
- Always use `/bin/bash` (3.2) semantics in scripts; `plutil -extract <keypath> raw -o - file.json` is the JSON reader.

### 0.3 Conventions
- **Language:** Swift, language mode 5, `@MainActor` on all UI types, `os.Logger(subsystem:"dev.persona.mode", category:…)` for logging (never `print` except in probes/selftest).
- **No `UserDefaults`, no `FileManager` writes outside the Trace Budget (§9.9).**
- **Probe convention:** `PersonaMode --probe <name> [args…] [--out <file.json>]` prints JSON to stdout (and to `--out` if given), exit code 0 on success. AX/TCC-dependent probes must be run **through the bundle**: `open -W -n "build/Persona Mode.app" --args --probe <name> --out /tmp/<name>.json` (running the raw binary from Terminal attributes permissions to Terminal).
- **Selftest convention:** each suite in `Sources/PersonaSelfTest/Suites/*.swift` exposes `func run(_ t: Harness)`; registered in `main.swift`; output lines `PASS <suite>/<case>` / `FAIL …`; exit 1 on any failure.
- Standard verification snippets used below:
  - **`V-BUILD`** → `swift build 2>&1 | tail -n 20` must show `Build complete!` and contain no `error:`.
  - **`V-TEST <suite>`** → `swift run persona-selftest <suite>` must exit 0 with only `PASS` lines.
- Commit after each task (`git init` in P1.1): message `P<phase>.<task>: <title>`.

### 0.4 Task template
```
- [ ] P#.# Title
  Files:  …                       (exact paths to create/modify)
  Details: …                      (what to implement)
  Verify: …                       (exact commands + expected result)
```

---

# PHASE 1 — Scaffolding, Fail-Safe State Snapshot/Restore Engine, `restore_macos.sh`

**Goal:** a system that can snapshot, mutate (Dock/Menu Bar only), and *always* restore — through every exit path — before any UI exists.

- [x] **P1.1 Project scaffolding**
  **Files:** `Package.swift`, `Makefile`, `.gitignore`, `README.md`, `scripts/doctor.sh`, `Sources/PersonaCore/PersonaCore.swift`, `Sources/PersonaMode/main.swift`, `Sources/PersonaSelfTest/main.swift`, directory skeleton from §10 (empty dirs with `.gitkeep`).
  **Details:**
  - `Package.swift`: tools-version `6.0`; `platforms: [.macOS(.v14)]`; `let swift5: [SwiftSetting] = [.swiftLanguageMode(.v5)]`; targets: `.target(name:"PersonaCore")`, `.executableTarget(name:"PersonaMode", dependencies:["PersonaCore"])`, `.executableTarget(name:"PersonaSelfTest", dependencies:["PersonaCore"])`, all with `swiftSettings: swift5`. Products: executables `PersonaMode` and `persona-selftest` (→ target `PersonaSelfTest`). **No `resources:`** (ADR-3).
  - `PersonaCore.swift`: `public enum PersonaCore { public static let version = "0.1.0" }`.
  - `PersonaMode/main.swift`: print `PersonaMode <version>` and exit (placeholder).
  - `Makefile` targets: `doctor build test app run restore verify-clean probe` (`probe: swift run PersonaMode --probe $(P)`); `app/run/verify-clean` may echo "not yet" until later phases.
  - `doctor.sh`: print `sw_vers`, `swift --version`, `xcode-select -p`, whether `plutil osascript defaults killall /usr/libexec/PlistBuddy` exist, `command -v fastfetch ghostty kitty wezterm alacritty cava`, signing identities (`security find-identity -v -p codesigning`), SIP status (`csrutil status`, informational), and **fails (exit 1) only if** `swift`/`plutil`/`osascript` are missing.
  - `.gitignore`: `.build/`, `build/`, `*.xcodeproj`, `.DS_Store`, `.swiftpm/`. `git init`.
  **Verify:**
  ```bash
  V-BUILD && swift run PersonaMode && swift run persona-selftest && make doctor
  ```
  Expected: build complete; `PersonaMode 0.1.0`; selftest prints `0 suites` and exits 0; doctor prints facts and exits 0.

- [x] **P1.2 Self-test harness**
  **Files:** `Sources/PersonaSelfTest/Harness.swift`, `Sources/PersonaSelfTest/main.swift`, `Sources/PersonaSelfTest/Suites/HarnessSuite.swift`.
  **Details:** `final class Harness { func suite(_ name: String, _ body: () throws -> Void); func expect(_ cond: @autoclosure () -> Bool, _ msg: String, file: StaticString = #fileID, line: UInt = #line); func expectEqual<T: Equatable>(_ a: T, _ b: T, …); func expectThrows(…) ; var failures: Int }`. `main.swift` registers suites in an ordered array `[(name, run)]`, filters by `CommandLine.arguments.dropFirst()` (no args = all), prints `PASS name/case` or `FAIL name/case: msg (file:line)`, summary `N passed, M failed`, `exit(failures == 0 ? 0 : 1)`. Env `SELFTEST_FORCE_FAIL=1` makes `HarnessSuite` add one failing check (used to test the harness itself).
  **Verify:**
  ```bash
  swift run persona-selftest harness ; echo "exit=$?"                        # exit=0
  SELFTEST_FORCE_FAIL=1 swift run persona-selftest harness ; echo "exit=$?"  # exit=1, shows FAIL line
  ```

- [x] **P1.3 Config model**
  **Files:** `Sources/PersonaCore/Config/AppConfig.swift`, `config/default-config.json`, `Sources/PersonaSelfTest/Suites/ConfigSuite.swift`.
  **Details:** `public struct AppConfig: Codable, Equatable` mirroring §12 (`wallpaper.mode`, `topBar{height,marginTop,marginSide,level}`, `hud`, `tiling{enabled,algorithm,splitRatio,gaps{outer,inner},snapBackOnDrag,floatApps}`, `border{enabled,width,cornerRadius,color,pulse}`, `terminal.preference`, `hotkeys`, `guardian{enabled,hangSeconds}`). Custom `init(from:)` using `decodeIfPresent` with defaults at every level so partial user JSON merges over defaults. `static func load(userFile: URL?) -> (AppConfig, [String] /*warnings*/)` — invalid JSON ⇒ defaults + warning (never throws). Validation clamps: `border.width ≤ gaps.inner` (warn), `splitRatio ∈ [0.2,0.8]`, hex colors match `^#[0-9a-fA-F]{6}$`. Enums: `WallpaperMode {overlay, system, none}`, `BarLevel {mainMenuMinusOne, statusBar}`, `TilingAlgorithm {dwindle, masterStack}`.
  **Verify:** selftests: defaults decode equals `config/default-config.json` (run from repo root); partial JSON `{"tiling":{"gaps":{"outer":20}}}` keeps `inner` default; garbage JSON ⇒ defaults + 1 warning; clamp tests. `V-TEST config`.

- [x] **P1.4 State model, atomic store, session lock**
  **Files:** `Sources/PersonaCore/State/{SystemStateSnapshot,StateFile,Mutation,RestoreLedger,StateStore,SessionLock}.swift`, `Sources/PersonaSelfTest/Suites/{StateSuite,LedgerSuite}.swift`.
  **Details (exact types, §9.2, §9.4):**
  - `public struct OriginalValue<T: Codable & Equatable>: Codable, Equatable { var present: Bool; var value: T? }`.
  - `SystemStateSnapshot { dock: DockSnapshot, menuBar: MenuBarSnapshot, wallpapers: [WallpaperSnapshot] }` (Foundation-only; wallpaper URL stored as `String`).
  - `enum Mutation: Codable, Equatable { case dockAutohide(Bool), menuBarAutohide(Bool), systemWallpaper(path: String), terminalProfile(name: String), tempDir(path: String) }`; `LedgerEntry { id, mutation, status: pending|applied|restored, ts }`.
  - `StateFile { schemaVersion = 1, sessionId, active, appPid, createdAt, macOS, wallpaperMode, snapshot, ledger, phase }`.
  - `StateStore(supportDir: URL)`: `load() -> StateFile?` (tries `state.json`, then `state.json.prev`), `save(_:)` = encode (sorted keys, pretty) → write `state.json.tmp` (0600) → `fsync` → copy current to `.prev` → `rename` → `fsync(dir)`; `delete()`; `supportDir` created `0700`. Reads `PERSONA_SUPPORT_DIR` override via a static `defaultDir()`.
  - `SessionLock(dir:)`: creates `session.lock` containing PID, takes `flock(LOCK_EX|LOCK_NB)` held for process life; `static func isHeldByOther(dir:) -> Bool`; `release()` deletes **last**.
  - `RestoreLedger`: `append(.pending)`, `markApplied(id)`, `markRestored(id)`, `pendingOrApplied` accessor.
  **Verify:** selftests — roundtrip equality; `OriginalValue(present:false)` survives; truncated/corrupt `state.json` falls back to `.prev`; no `.tmp` left after save; file mode is `0600`; second `SessionLock` acquire in-process on a fresh fd fails; ledger transitions. `V-TEST state ledger`.

- [x] **P1.5 Read-only system adapter + `--probe snapshot`**
  **Files:** `Sources/PersonaCore/Lifecycle/SystemAdapter.swift` (protocol + value types), `Sources/PersonaMode/Lifecycle/ShellRunner.swift`, `Sources/PersonaMode/System/RealSystemAdapter.swift`, `Sources/PersonaMode/Probes/{Probe,ProbeSnapshot}.swift`, `Sources/PersonaMode/main.swift` (arg dispatch).
  **Details:**
  - `protocol SystemAdapter { func readDockAutohide() -> OriginalValue<Bool>; func readMenuBarKeys() -> (hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>); func readScripted() -> (dock: Bool?, menuBar: Bool?); func readWallpapers() -> [WallpaperSnapshot]; func setDockAutohide(_ v: Bool) throws; func setMenuBarAutohide(_ v: Bool) throws; func deleteDockAutohideKey() throws; func setMenuBarKeys(…) throws; func setWallpapers(_:) throws; func isStable() -> Bool }` (writers throw `.notImplemented` for now).
  - `ShellRunner.run(_ exe: String, _ args: [String], timeout: TimeInterval = 3) -> (status: Int32, out: String, err: String, timedOut: Bool)` using `Process` + pipes + semaphore; kills on timeout. `runAppleScript(_:)` wraps `/usr/bin/osascript -e`.
  - `RealSystemAdapter` reads: `CFPreferencesCopyAppValue` (`autohide`/`com.apple.dock`; `_HIHideMenuBar` & `AppleMenuBarVisibleInFullscreen`/`kCFPreferencesAnyApplication`), scripted values via `tell application "System Events" to get autohide of dock preferences` and `autohide menu bar of dock preferences`, wallpapers via `NSWorkspace.shared.desktopImageURL(for:)` + `desktopImageOptions(for:)` per `NSScreen` (UUID via `CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]))`), `isRestorable` = file URL, exists, readable, regular file, extension in `heic jpg jpeg png tiff`.
  - `main.swift`: parse `--probe <name> [--out f] [--no-applescript]`; `snapshot` probe prints the full `SystemStateSnapshot` JSON. `--no-applescript` skips scripted reads (avoids the Automation prompt).
  **Verify (read-only, safe):**
  ```bash
  V-BUILD && swift run PersonaMode --probe snapshot --out /tmp/snap.json
  plutil -extract dock.autohide.present raw -o - /tmp/snap.json   # → false on this machine
  plutil -extract wallpapers.0.isRestorable raw -o - /tmp/snap.json
  defaults read com.apple.dock autohide 2>&1 | head -1            # unchanged: "does not exist"
  ```
  (First run may show a macOS Automation prompt for System Events → Allow.)

- [x] **P1.6 `scripts/restore_macos.sh` v1 + script tests**
  **Files:** `scripts/restore_macos.sh`, `scripts/test_restore_script.sh`, `scripts/fixtures/state_hidden.json`, `scripts/fixtures/state_corrupt.json`.
  **Details:** implement per §9.8: flags `--dry-run --force-defaults --kill-app --reason <s> --support-dir <p>`; `PERSONA_SUPPORT_DIR` honored; `mkdir`-mutex `restore.lock.d` (stale-mutex cleanup after 30 s); JSON via `plutil -extract … raw`; bash 3.2 only; `run()` helper that prints and (unless `--dry-run`) executes each command. Dock: if original present → `osascript … set autohide of dock preferences to <orig>`; if absent → set `false` then `defaults delete com.apple.dock autohide`; fallback (osascript failure) `defaults write/delete` + `killall Dock`. Menu bar per spike result placeholder: scripted set to original, then reconcile raw keys (`defaults delete NSGlobalDomain _HIHideMenuBar` etc.). Wallpaper via JXA only if `wallpaperMode == system`. Safe temp-path deletion with prefix guard. Missing/corrupt state ⇒ force-defaults branch. Always remove lock files last. Exit codes `0/2/3`.
  `test_restore_script.sh`: runs the script with `--dry-run` against fixtures in temp support dirs and asserts (with `grep -q`) the exact commands emitted; asserts missing-state path emits `autohide … false`; asserts a malicious `tempdir` path (`/Users`) is **refused**; runs the script under `/bin/bash` explicitly.
  **Verify:**
  ```bash
  /bin/bash -n scripts/restore_macos.sh && /bin/bash scripts/test_restore_script.sh   # prints "ALL RESTORE SCRIPT TESTS PASSED"
  ```

- [x] **P1.7 ⚠ REAL MUTATION — Spike S-1: live Dock/Menu Bar auto-hide mechanisms on macOS 26**
  **Files:** `docs/SPIKE_RESULTS.md` (create).
  **Details:** Determine empirically and record: (a) does `tell application "System Events" to set autohide menu bar of dock preferences to true` hide the native menu bar immediately (no logout)? (b) Does it create/modify `_HIHideMenuBar`/`AppleMenuBarVisibleInFullscreen`? (c) Same for Dock `autohide` (does it create the `autohide` key; is `killall Dock` needed)? (d) Does deleting the key after setting `false` change behavior? (e) Does the result differ via `defaults write NSGlobalDomain _HIHideMenuBar -bool true` + `killall SystemUIServer`? Use this **self-healing one-liner pattern** for each experiment:
  ```bash
  make restore; defaults read NSGlobalDomain _HIHideMenuBar 2>&1 | head -1
  osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to true'; sleep 6
  defaults read NSGlobalDomain _HIHideMenuBar 2>&1 | head -1
  osascript -e 'tell application "System Events" to get autohide menu bar of dock preferences'
  osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to false'; ./scripts/restore_macos.sh
  ```
  Record observed behavior (use `screencapture -x /tmp/spike_menubar.png` and view it if permitted), chosen mechanism, and any caveats. **Update `restore_macos.sh` and `ARCHITECTURE.md §9.5` to match.** If Menu Bar hiding is *not* achievable live, set `menuBar.mechanism="none"` — the app then does not hide the native menu bar (bar overlaps; level 23 keeps native menus reachable) and snapshot still records the keys.
  **Verify:** `docs/SPIKE_RESULTS.md` contains a "S-1" section with Decision lines; afterwards `defaults read NSGlobalDomain _HIHideMenuBar` and `defaults read com.apple.dock autohide` report the same as the P1.5 snapshot (absent), and `restore_macos.sh --dry-run` output is consistent with the chosen mechanism.

- [x] **P1.8 System mutator, snapshot service, write adapters (with crash-injection tests)**
  **Files:** `Sources/PersonaCore/Lifecycle/{SnapshotService,SystemMutator,RecoveryManager}.swift`, `Sources/PersonaCore/Lifecycle/FakeSystemAdapter.swift` (public, used by selftest + dry run), `Sources/PersonaMode/System/{RealSystemAdapter+Write,DryRunAdapter}.swift`, `Sources/PersonaSelfTest/Suites/MutatorSuite.swift`.
  **Details:**
  - `SnapshotService.begin(store:lock:adapter:mode:) throws -> StateFile`: **I2** — if `store.load()` has `active==true` **or** `SessionLock.isHeldByOther==false` with leftover `session.lock` ⇒ call `RecoveryManager.recoverIfStale` first; then read snapshot via adapter; write `StateFile(active:true, phase:.snapshotted)`; acquire lock. Returns only after durable (I1).
  - `SystemMutator.apply(_ m: Mutation)`: `ledger.append(pending)` → `store.save` → adapter call → `markApplied` → `store.save` (I3). Exhaustive `switch` over `Mutation` (I7).
  - Real writers: Dock/Menu Bar via mechanism from S-1 (System Events script, fallback `defaults`+`killall Dock`), each guarded by `ShellRunner` timeout; wallpaper via `NSWorkspace.setDesktopImageURL` (system mode only).
  - `DryRunAdapter` wraps a real adapter for reads and logs writes to `Logger` + stdout (`DRYRUN: set dock autohide=true`).
  - `FakeSystemAdapter`: in-memory "world" struct with an `onWrite` hook; supports injecting failures per call.
  **Verify:** `V-TEST mutator` — includes (1) apply→restore returns world to original, (2) **crash injection:** for every `k` in `0…N` of the apply sequence, drop all in-memory objects after step `k`, construct fresh `RecoveryManager` against the same store + same mutated fake world, assert world == original, (3) pending-only ledger entries are restored, (4) stale-active at launch recovers *before* snapshot (second snapshot never equals mutated world), (5) absent-key originals restore to "absent".

- [x] **P1.9 Restore service, signal guard, AppDelegate lifecycle hooks**
  **Files:** `Sources/PersonaCore/Lifecycle/RestoreService.swift`, `Sources/PersonaMode/Lifecycle/{SignalGuard,HeartbeatPump}.swift`, `Sources/PersonaMode/App/{AppDelegate,LifecycleController,MainMenu}.swift`, `Sources/PersonaMode/main.swift`, `Sources/PersonaSelfTest/Suites/RestoreSuite.swift`.
  **Details:**
  - `RestoreService.restoreAll(reason:) -> RestoreReport` implements §9.6: phase flush → Dock → Menu Bar → Wallpaper (each in `do/catch`; independent) → `modules.stopAll()` closure hooks → temp/terminal cleanup → **verify** by re-reading adapter and diffing against snapshot → delete state files, `session.lock` last; else keep `active=true`. Idempotent (I4); total budget 2.5 s enforced by adapter-level timeouts. `RestoreReport` lists per-step ok/err and `verified: Bool`.
  - `SignalGuard.install()`: for `SIGINT, SIGTERM, SIGHUP, SIGQUIT` → `signal(sig, SIG_IGN)` + `DispatchSource.makeSignalSource(queue: .main)` → `NSApp.terminate(nil)`. Fatal signals (`SEGV, BUS, ILL, ABRT, TRAP, FPE`) via `sigaction` handler that only calls `_exit(128+sig)` (async-signal-safe). `NSSetUncaughtExceptionHandler` → `RestoreService.shared?.restoreAll(.exception)` then default handler.
  - `HeartbeatPump`: background `DispatchSourceTimer` (1 s) touches `heartbeat` only if main-thread pong (updated by a main-queue timer every 1 s) is < 8 s old.
  - `AppDelegate.applicationShouldTerminate` → runs `restoreAll(.userQuit)` synchronously, returns `.terminateNow`; `applicationWillTerminate` runs `restoreAll` again if not yet done (idempotent); observe `NSWorkspace.willPowerOffNotification`. `MainMenu.install()` builds `NSApp.mainMenu` with *Quit Persona Mode ⌘Q* (LSUIElement apps still honor key equivalents when active).
  - `main.swift` modes: GUI (default) | `--probe` | `--ctl <cmd>` (stub now) | `--restore-only` (runs `RecoveryManager` headlessly with `RealSystemAdapter` — dev aid).
  - `LifecycleController.start()` (Phase 1 version): `SnapshotService.begin` → spawn guardian (P1.10) → apply `dockAutohide(true)` + `menuBarAutohide(true)` (per S-1) **only when env `PERSONA_PHASE1_DEMO=1`**; otherwise only dry-run logs.
  **Verify:** `V-TEST restore` — order of calls recorded by FakeSystemAdapter is Dock, MenuBar, Wallpaper (I5); failure injected in Dock still restores Menu Bar; double restore is a no-op; verify mismatch keeps `active=true` and state file; successful restore leaves an empty support dir. Plus `V-BUILD`.

- [x] **P1.10 Guardian watchdog + launcher + script tests**
  **Files:** `scripts/guardian.sh`, `scripts/test_guardian.sh`, `Sources/PersonaMode/Lifecycle/GuardianLauncher.swift`.
  **Details:** `guardian.sh <appPid> <supportDir> <restoreScript>` per §9.8 (0.5 s loop; lock missing ⇒ exit 0; pid dead ⇒ `restore --reason guardian-crash`; heartbeat older than `hangSeconds` (env `PERSONA_HANG_SECONDS`, default 15) ⇒ `restore --reason guardian-hang --kill-app`). `GuardianLauncher.spawn(pid:supportDir:)` uses `posix_spawn` with `POSIX_SPAWN_SETSID` (+ `posix_spawn_file_actions` redirecting stdio to `/dev/null`); script path resolved from bundle `Contents/Resources/scripts` else `PERSONA_SCRIPTS_DIR` else `<repo>/scripts`; respects `PERSONA_NO_GUARDIAN=1`; records guardian PID in `session.lock` metadata.
  `test_guardian.sh` (all in a temp dir; the "restore script" is a stub that `touch`es `$DIR/RESTORED`): case A fake app `sleep 300 &` is killed with `-9` ⇒ marker appears within 3 s; case B lock deleted ⇒ guardian exits, **no** marker; case C app alive but heartbeat stale (set mtime back 60 s with `touch -t`) ⇒ marker + app killed; case D guardian survives when its spawning shell exits (spawn via `( setsid-like perl -e 'use POSIX; setsid()' …)` or the Swift launcher).
  **Verify:** `/bin/bash -n scripts/guardian.sh && /bin/bash scripts/test_guardian.sh` → `ALL GUARDIAN TESTS PASSED`; `V-BUILD`.

- [x] **P1.11 ⚠ REAL MUTATION — Phase-1 end-to-end: zero-trace across exit paths**
  **Files:** `scripts/verify_clean_state.sh` (v1), `Makefile` (`verify-clean` → script).
  **Details:** `verify_clean_state.sh --phase 1`: defines `fingerprint()` printing: `defaults read` of the three keys (normalized "ABSENT"), scripted `autohide`/`autohide menu bar` values, per-screen wallpaper URL via JXA, `ls` of support dir and `$TMPDIR/PersonaMode`, `pgrep -fl 'guardian.sh|PersonaMode'`. For each scenario: capture fingerprint → launch `PERSONA_PHASE1_DEMO=1 swift run PersonaMode` (or the built binary from `swift build --show-bin-path`) in background with a **fresh `PERSONA_SUPPORT_DIR`** only for dry-run scenarios; real scenarios use the real dir → wait until `state.json` exists and Dock/Menu Bar are hidden (poll scripted value) → apply exit path → wait ≤ 4 s → capture fingerprint → `diff` must be empty. Scenarios: **(1)** SIGINT, **(2)** SIGTERM, **(3)** `kill -9` (guardian must restore), **(4)** `kill -9` with `PERSONA_NO_GUARDIAN=1` then run `restore_macos.sh`, **(5)** `kill -STOP` (hang) ⇒ guardian restores within hangSeconds (use `PERSONA_HANG_SECONDS=4`), **(6)** stale state: `kill -9` with no guardian, then *launch app again* ⇒ it must recover first (I2) and snapshot equals original. Each scenario self-heals with `restore_macos.sh` in a `trap`.
  **Verify:** `make verify-clean` prints `SCENARIO n: PASS` ×6 and `PHASE 1 ZERO-TRACE: PASS`; final manual sanity: Dock and Menu Bar behave as before.

### ✅ Phase 1 Gate
`V-BUILD`; `swift run persona-selftest` (all green); `/bin/bash scripts/test_restore_script.sh`; `/bin/bash scripts/test_guardian.sh`; `make verify-clean` green; `docs/SPIKE_RESULTS.md` has S-1.

---

# PHASE 2 — AppKit Window Host Manager (Top Bar `NSPanel` + Click-Through Desktop Overlay `NSWindow`)

**Goal:** correct windows, levels, behaviors, notch handling, multi-display — with placeholder content (solid-color rectangles).

- [x] **P2.1 Screen model & coordinate helpers**
  **Files:** `Sources/PersonaCore/Layout/CoordinateSpace.swift`, `Sources/PersonaMode/Windows/ScreenModel.swift`, `Sources/PersonaSelfTest/Suites/CoordSuite.swift`.
  **Details:** Core: `CoordinateSpace.toAX(_ r: CGRect, primaryHeight: CGFloat)`/`toAppKit(...)` (`y' = H − (y + h)`), pure & tested for single and stacked/offset multi-display geometries (negative origins). PersonaMode: `ScreenModel { id: CGDirectDisplayID, uuid, frame, visibleFrame, safeTop: CGFloat, auxLeft: CGRect?, auxRight: CGRect?, backingScale }` built from `NSScreen` (`safeAreaInsets`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`); `ScreenObserver` publishes on `NSApplication.didChangeScreenParametersNotification`.
  **Verify:** `V-TEST coords` (round-trip equality incl. negative-origin secondary display; known-value table).

- [x] **P2.2 Window level constants & base panel classes**
  **Files:** `Sources/PersonaMode/Windows/{WindowLevels,PersonaPanel}.swift`.
  **Details:** `enum WindowLevels { static var desktopOverlay: NSWindow.Level { .init(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1) }; static var topBar: NSWindow.Level { .init(rawValue: Int(NSWindow.Level.mainMenu.rawValue) - 1) }; static let launcher = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1); static let border = NSWindow.Level.floating }` (+ `.statusBar` alternative via config). `class PersonaPanel: NSPanel` — `init(contentRect:)` with `[.borderless,.nonactivatingPanel]`, `isOpaque=false`, `backgroundColor=.clear`, `hasShadow=false`, `hidesOnDeactivate=false`, `isReleasedWhenClosed=false`, `canBecomeKey/Main` overridable flags, **`override func constrainFrameRect(_ r: NSRect, to s: NSScreen?) -> NSRect { r }`**, `animationBehavior = .none`.
  **Verify:** `V-BUILD`.

- [x] **P2.3 `TopBarPanel`**
  **Files:** `Sources/PersonaMode/Windows/TopBarPanel.swift`.
  **Details:** frame per §5/§8.1: `x = screen.frame.minX + marginSide`, `width = screen.frame.width − 2*marginSide`, `height = max(cfg.height, screen.safeTop)`, `y = screen.frame.maxY − marginTop − height`; level from `cfg.topBar.level`; `collectionBehavior = [.canJoinAllSpaces,.stationary,.ignoresCycle]`; content = `NSHostingView(rootView: Color(red:0, green:0.85, blue:1).opacity(0.85))` placeholder; `canBecomeKey=false`. `reposition(for:)` for screen changes.
  **Verify:** deferred to P2.6 probe (`V-BUILD` now).

- [x] **P2.4 `DesktopOverlayWindow`**
  **Files:** `Sources/PersonaMode/Windows/DesktopOverlayWindow.swift`.
  **Details:** `NSWindow(contentRect: screen.frame, styleMask:.borderless, backing:.buffered, defer:false)`; `level = WindowLevels.desktopOverlay`; `ignoresMouseEvents = true`; `collectionBehavior = [.canJoinAllSpaces,.stationary,.ignoresCycle]`; `isOpaque = (mode == .overlay)`; `backgroundColor = (mode == .overlay) ? midnight : .clear`; `hasShadow=false`; `sharingType = .none`; `isExcludedFromWindowsMenu = true`; `canBecomeKey/Main = false` (override). Placeholder content: translucent diagonal stripe `Canvas`.
  **Verify:** deferred to P2.6.

- [x] **P2.5 `WindowHostManager`**
  **Files:** `Sources/PersonaMode/Windows/WindowHostManager.swift`, `Sources/PersonaMode/App/LifecycleController.swift` (modify).
  **Details:** owns `[CGDirectDisplayID: (bar: TopBarPanel, overlay: DesktopOverlayWindow)]`; `start(config:)` creates & `orderFrontRegardless()`; rebuild on screen param change / `NSWorkspace.didWakeNotification` / `activeSpaceDidChangeNotification` (re-assert level + order); `stop()` `orderOut(nil)` + `close()` + release (registered as a `RestoreService` module-stop hook). HUD content only on primary when `hud.primaryScreenOnly`. Lifecycle wiring: after `SnapshotService.begin` → `WindowHostManager.start` (in dry-run mode no system mutation).
  **Verify:** `V-BUILD`.

- [x] **P2.6 `--probe windows` + Spike S-2 (levels on Tahoe) + Spike S-5 (hosting transparency)**
  **Files:** `Sources/PersonaMode/Probes/ProbeWindows.swift`, `docs/SPIKE_RESULTS.md`.
  **Details:** `--probe windows --seconds 2 --out f`: with `PERSONA_DRY_RUN=1` semantics, start `WindowHostManager`, wait, then for **each window owned by this PID** from `CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)` emit `{role: bar|overlay, layer: kCGWindowLayer, bounds, alpha, onScreen}` plus `NSWindow` introspection `{ignoresMouseEvents, canBecomeKey, level.rawValue, collectionBehavior.rawValue}`; also emit `constants: {desktopWindow, desktopIconWindow, mainMenu, statusBar, popUpMenu}` from `CGWindowLevelForKey`. Spike notes in `docs/SPIKE_RESULTS.md` (S-2): (1) bar layer == 23, overlay layer == desktopIcon−1; (2) **manual:** hover top edge — native menu bar must reveal *above* our bar; (3) **manual:** put an app fullscreen — bar hidden; (4) bar frame on the notched built-in display clears the notch; (5) clicks on desktop icons pass through the overlay; (6) S-5: placeholder SwiftUI view renders with true transparency (no black box).
  **Verify:**
  ```bash
  V-BUILD && PERSONA_DRY_RUN=1 swift run PersonaMode --probe windows --seconds 2 --out /tmp/win.json
  plutil -extract windows.0.layer raw -o - /tmp/win.json ; plutil -extract windows.1.layer raw -o - /tmp/win.json
  plutil -extract windows.0.ignoresMouseEvents raw -o - /tmp/win.json   # overlay → true; bar → false
  ```
  Expected: one window with layer `23` (bar, `ignoresMouseEvents=false`, `canBecomeKey=false`), one with layer `desktopIconWindow−1` (`ignoresMouseEvents=true`). Manual checks recorded as PASS/FAIL in SPIKE_RESULTS.

### ✅ Phase 2 Gate
Probe asserts above; all Phase 1 gates still green (`swift run persona-selftest`); quitting the dry-run GUI (`⌘Q`) leaves no windows (`--probe windows` shows 0 windows after `stop()`).

---

# PHASE 3 — Persona 3 Reload UI/UX (Top Bar, Shapes, Telemetry, HUD)

**Goal:** the visuals and live data. Verified headlessly with `ImageRenderer` PNGs and `--probe` JSON.

- [x] **P3.1 Fonts & design tokens**
  **Files:** `scripts/fetch_fonts.sh`, `Resources/fonts/*`, `Sources/PersonaCore/Theme/ThemeTokens.swift`, `Sources/PersonaMode/UI/Theme/{ThemeColors,Fonts}.swift`, `Sources/PersonaSelfTest/Suites/ThemeSuite.swift`.
  **Details:** `fetch_fonts.sh` downloads (curl `-fsSL`) from `https://github.com/google/fonts/raw/main/ofl/rajdhani/{Rajdhani-SemiBold.ttf,Rajdhani-Bold.ttf,OFL.txt}` and `…/ofl/bebasneue/{BebasNeue-Regular.ttf,OFL.txt}` into `Resources/fonts/` (rename licenses `OFL-rajdhani.txt`, `OFL-bebasneue.txt`). `ThemeTokens` (Core, hex strings): `cyan #00d8ff`, `midnight #0a192f`, `abyss #050c1a`, `ice #e8f6ff`, `azure #1f6bff`, `steel #3a5a7a`, `warn #ffd24a`, `alert #ff3b5c`, `darkHour #5dffcf`; `skewDegrees = -12`; radii/spacings. `ThemeColors`: SwiftUI `Color(hex:)` mapping. `Fonts.register()`: `CTFontManagerRegisterFontsForURL(url, .process, &err)` for each file in `Bundle.main.resourceURL/fonts` else `PERSONA_RESOURCE_DIR/fonts` else `<repo>/Resources/fonts` (**process scope only → zero trace**); helpers `Fonts.display(size)`, `Fonts.body(size)` with fallback chain `Rajdhani → "Avenir Next Condensed" → .system(.rounded)`.
  **Verify:** `bash scripts/fetch_fonts.sh && file Resources/fonts/*.ttf` (each "TrueType Font data"); `V-TEST theme` (hex parse valid, contrast ratio `ice` on `midnight` ≥ 7, `cyan` on `midnight` ≥ 7); probe `swift run PersonaMode --probe fonts` prints `{"rajdhani": true, "bebas": true}` (checks `NSFont(name:)` non-nil).

- [x] **P3.2 Skewed shape library**
  **Files:** `Sources/PersonaMode/UI/Shapes/{SkewedPill,AngledPanel,ChevronBadge,HexRing,Halftone}.swift`, `Sources/PersonaMode/Probes/ProbeRender.swift`.
  **Details:** `SkewedPill: Shape` (parallelogram with horizontal inset `h·tan(skew)`, animatable `skew`), `AngledPanel` (rectangle with one clipped corner top-right + skewed left edge, optional inner stroke inset), `ChevronBadge` (arrow-ended tag), `HexRing` (regular hexagon stroke, rotation param), `Halftone` (`Canvas` dot grid, dot radius gradient along an axis). All take their skew from `ThemeTokens.skewDegrees`. `ProbeRender`: `--probe render <name> <out.png> [--w W --h H --scale 2]` using `ImageRenderer` on `@MainActor` (`renderer.scale`, `cgImage` → PNG via `CGImageDestination`); `name ∈ shapes|topbar|hud|launcher|wallpaper`. `shapes` renders a contact sheet on `abyss` background.
  **Verify:**
  ```bash
  V-BUILD && swift run PersonaMode --probe render shapes /tmp/shapes.png --w 900 --h 400 && file /tmp/shapes.png && sips -g pixelWidth /tmp/shapes.png
  ```
  Expected PNG 900pt×400pt @2x. **Open the PNG** and confirm parallelograms are skewed (not rectangles), cyan on midnight, no clipping.

- [x] **P3.3 Telemetry samplers + math (selftested)**
  **Files:** `Sources/PersonaCore/Telemetry/{CPUMath,MemoryMath}.swift`, `Sources/PersonaMode/Telemetry/{TelemetryStore,CPUSampler,MemorySampler,BatterySampler,WiFiSampler,VolumeSampler}.swift`, `Sources/PersonaSelfTest/Suites/TelemetrySuite.swift`, `Sources/PersonaMode/Probes/ProbeTelemetry.swift`.
  **Details:**
  - `CPUMath.usage(prev:[UInt32 ticks×4 per core], cur:) -> Double` (user+system+nice over total deltas; clamp 0–100). `MemoryMath.usedPercent(active:wired:compressed:total:)` (Activity-Monitor-style "used" = active+wired+compressed).
  - `CPUSampler`: `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` every 1 s, deallocate with `vm_deallocate`. `MemorySampler`: `host_statistics64(HOST_VM_INFO64)` + `hw.memsize`. `BatterySampler`: `IOPSCopyPowerSourcesInfo/IOPSCopyPowerSourcesList`, event-driven via `IOPSNotificationCreateRunLoopSource`; desktop Macs ⇒ `hasBattery=false` ⇒ pill hidden. `WiFiSampler`: `NWPathMonitor` (connected, `usesInterfaceType(.wifi/.wiredEthernet)`) + `CWWiFiClient.shared().interface()?.rssiValue()` every 5 s ⇒ 0–4 bars (**no SSID**, §6). `VolumeSampler`: CoreAudio default output device → `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` (fallback per-channel scalar) + `kAudioDevicePropertyMute`, with `AudioObjectAddPropertyListenerBlock` for change events.
  - `TelemetryStore` (`@MainActor @Observable`): aggregates; timers are `DispatchSourceTimer`s on a utility queue; **start/stop** methods (stopped on restore); ≤ 1 UI update per second.
  - Probe: `--probe telemetry --samples 3` emits 3 samples (1 s apart) `{cpu, ram, batteryPercent?, charging?, wifi:{connected,bars}, volume:{percent,muted}}`.
  **Verify:** `V-TEST telemetry` (golden vectors for deltas, clamps, wrap-around of `UInt32` counters); `swift run PersonaMode --probe telemetry --samples 3 --out /tmp/t.json && plutil -extract samples.2.cpu raw -o - /tmp/t.json && plutil -extract samples.0.ram raw -o - /tmp/t.json` (numbers in 0–100; RAM within ±15 % of `memory_pressure | grep 'free percentage'` inverse sanity).

- [x] **P3.4 Focus tracker (app name; title provider hook)**
  **Files:** `Sources/PersonaMode/Telemetry/FocusTracker.swift`.
  **Details:** `NSWorkspace.shared.notificationCenter` `didActivateApplicationNotification` → `AppState.focusedApp = app.localizedName?.uppercased()`. Protocol `FocusTitleProvider { func title(for pid: pid_t) -> String? }` with default `NullTitleProvider`; Phase 4 injects the AX implementation. Ignore Persona itself.
  **Verify:** `V-BUILD`; probe `--probe focus --seconds 3` prints `{app, bundleId}` of the frontmost app (run in a terminal → "TERMINAL"/"GHOSTTY"…).

- [x] **P3.5 Space provider (workspace indicators)** — includes Spike S-3
  **Files:** `Sources/PersonaMode/Telemetry/SpaceProvider.swift`.
  **Details:** `@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32`, `CGSCopyManagedDisplaySpaces(Int32) -> CFArray`, `CGSGetActiveSpace(Int32) -> UInt64`, resolved with `dlsym(RTLD_DEFAULT, …)` first (graceful absence ⇒ `available=false`). Parse spaces for the display containing the bar (key `Spaces`, `ManagedSpaceID`, `Current Space`). Output `SpaceInfo { index(1…n), isActive, isOccupied? }` clamped to 5. Refresh on `activeSpaceDidChangeNotification`. `switchTo(_ n: Int)`: posts synthetic `Ctrl+N` via `CGEvent` (keycodes 18–23 for 1–5) only if symbolic hotkey for "Switch to Desktop N" is enabled (read `com.apple.symbolichotkeys` AppleSymbolicHotKeys ids 118–122 `enabled`); else emits `AppState.hint`.
  **Verify:** probe `--probe spaces` prints `{available, count, active}`; result recorded as S-3 in `docs/SPIKE_RESULTS.md`; `available=false` must still yield a sane single-pill fallback (unit-test the fallback mapping in `ThemeSuite` or a small Core function).

- [x] **P3.6 Top bar view (notch-aware)**
  **Files:** `Sources/PersonaMode/UI/TopBar/{TopBarView,WorkspacePills,FocusLabel,TelemetryPills,ClockBadge,QuitButton}.swift`, `Sources/PersonaMode/Windows/TopBarPanel.swift` (modify to host `TopBarView`).
  **Details:** per §8.1. Background: `AngledPanel` fill `midnight @ 92 %` with 1 pt cyan hairline and a short cyan "tick" accent at the left. Workspace pills use `SkewedPill` (active: cyan fill + `midnight` bold digit + glow shadow; inactive: stroke `steel`). Focus label: app name (Bebas 15) + title (Rajdhani 13, `.lineLimit(1)`, `.truncationMode(.tail)`, max 40 % width). Telemetry pills as `SkewedPill` with icon (SF Symbols: `cpu`, `memorychip`, `battery.*`, `wifi`/`wifi.slash`, `speaker.wave.2`/`speaker.slash`) + number; warn/alert thresholds (§8.1). Clock: two-line badge (`HH:mm` display font 20, `EEE dd MMM`). `QuitButton`: angled red-tinted pill `QUIT` → `CommandRouter.send(.exitPersona)`; `.help("Return to macOS")`. Notch: if `ScreenModel.auxLeft/auxRight` present, lay out left cluster inside `auxLeft`, right cluster inside `auxRight` (Spacer replaced by the notch gap). Every interactive element gets `.accessibilityIdentifier("topbar.<name>")`.
  **Verify:**
  ```bash
  swift run PersonaMode --probe render topbar /tmp/topbar.png --w 1440 --h 34 --scale 2 && file /tmp/topbar.png
  ```
  Open the PNG: pills skewed, text legible, nothing clipped; repeat with `--notch 180` (probe option that simulates a 180pt notch gap) and confirm the center gap.

- [x] **P3.7 Now Playing service**
  **Files:** `Sources/PersonaMode/Telemetry/NowPlayingService.swift`, `Sources/PersonaMode/UI/HUD/NowPlayingWidget.swift`.
  **Details (ADR-7):** `DistributedNotificationCenter.default()` observers for `com.apple.Music.playerInfo` (keys `Name`, `Artist`, `Album`, `Player State` ∈ Playing/Paused/Stopped) and `com.spotify.client.PlaybackStateChanged` (keys `Name`, `Artist`, `Player State`). Seed once at start: for each of Music/Spotify that `NSRunningApplication.runningApplications(withBundleIdentifier:)` reports running (`com.apple.Music`, `com.spotify.client`), run AppleScript `tell application id "…" to get {name of current track, artist of current track, player state as string}` with timeout 2 s (**never** when not running). Publish `NowPlaying?` to `AppState`. Widget: skewed comic-book frame (`AngledPanel` + `Halftone` corner), title (display font, 1 line marquee if > width), artist, play/pause glyph, animated 3-bar equalizer when playing; "NOTHING PLAYING" idle state.
  **Verify:** `swift run PersonaMode --probe nowplaying --seconds 3` prints `{source, state, title, artist}` or `{"state":"none"}`; inject a synthetic notification and assert parsing: `swift run PersonaMode --probe nowplaying-inject --out /tmp/np.json` (probe posts a fake `com.spotify.client.PlaybackStateChanged` userInfo to itself and asserts `title == "TEST"`).

- [x] **P3.8 Desktop HUD: wallpaper, widgets, ambient accents, Dark Hour phase**
  **Files:** `Sources/PersonaCore/Theme/DarkHourPhase.swift`, `Sources/PersonaMode/UI/HUD/{HUDView,WallpaperView,DateTimeWidget,AmbientAccents}.swift`, `Sources/PersonaMode/Windows/DesktopOverlayWindow.swift` (modify), `Sources/PersonaSelfTest/Suites/ThemeSuite.swift` (extend).
  **Details:** `DarkHourPhase.phase(for: Date, calendar:, force: Bool?) -> {darkHour, earlyMorning, daytime, evening, lateNight}` per §8.2 (`00:00–00:59` = darkHour). `WallpaperView` (only if `wallpaper.mode == .overlay`): `LinearGradient(abyss→midnight)`, large crescent (two overlapping circles via `Path` even-odd) with radial glow (darkHour ⇒ `darkHour` tint), faint hex grid, diagonal light bars. `DateTimeWidget` (top-right under bar): `AngledPanel` with big `HH:mm` (updates on the minute boundary via `TimelineView(.periodic(from:by:60))`), weekday/date, phase tag chip. `NowPlayingWidget` bottom-left. `AmbientAccents`: `TimelineView(.animation(minimumInterval: 1/Double(cfg.hud.fps)))` + `Canvas` rotating `HexRing`s and drifting skewed bars; **pause conditions** (§8.2) via `AppState.ambientPaused`. `DesktopOverlayWindow` hosts `HUDView` (`NSHostingView`, `.allowsHitTesting(false)`).
  **Verify:** `V-TEST theme` (phase table incl. 00:00, 00:59, 01:00, 23:59, forced override, DST-safe via fixed `Calendar`); `swift run PersonaMode --probe render hud /tmp/hud.png --w 1512 --h 982 --scale 1` and `--probe render wallpaper /tmp/wp.png`; open PNGs and check composition (moon, widgets in corners, nothing overlapping the top 50pt bar zone).

- [x] **P3.9 Wire Phase 3 into the lifecycle + perf budget check**
  **Files:** `Sources/PersonaMode/App/{AppState,LifecycleController}.swift`, `scripts/perf_check.sh`.
  **Details:** Start `TelemetryStore`, `NowPlayingService`, `FocusTracker`, `SpaceProvider` after window hosts; register stop hooks with `RestoreService`. `scripts/perf_check.sh [seconds=60]`: launches dry-run GUI, samples `ps -o %cpu=,rss= -p $PID` each 2 s, prints avg CPU & max RSS, kills it with SIGTERM, asserts budgets of §14 (CPU ≤ 4 %, RSS ≤ 150 MB), also runs again with `PERSONA_HUD_ANIMATION=0` env override (≤ 1 %).
  **Verify:** `V-BUILD && PERSONA_DRY_RUN=1 bash scripts/perf_check.sh 30` → `PERF OK`. **Manual:** launch GUI dry-run, confirm bar + HUD visible; `⌘Q` removes them.

### ✅ Phase 3 Gate
Selftests green; PNG renders reviewed; telemetry/nowplaying/spaces probes OK; perf OK; Phase 1 `make verify-clean` still green (windows appear/disappear with the session).

---

# PHASE 4 — Active-Window Border Renderer & Tiling Engine (Accessibility API)

**Goal:** tile windows with gaps below the bar; glowing border follows focus; fully reversible.

- [x] **P4.1 Layout engine (pure Core)**
  **Files:** `Sources/PersonaCore/Layout/{LayoutEngine,Gaps}.swift`, `Sources/PersonaSelfTest/Suites/LayoutSuite.swift`.
  **Details:** per §8.3: `struct BarInset { marginTop, height }`, `struct Gaps { outer, inner }`, `typealias WindowID = UInt32`, `LayoutEngine.layout(ids:screen:bar:gaps:algorithm:splitRatio:) -> [WindowID: CGRect]` (AX/top-left coords), dwindle + masterStack; integer rounding; deterministic ordering; empty/1-window cases; guard against rects below 100×60 by falling back to **stacking remaining windows in last cell** (never zero/negative sizes).
  **Verify:** `V-TEST layout` with assertions: 1 window fills `usable`; 2 windows split with seam == `inner`; 5 windows no overlaps & all inside `usable`; **every `rect.minY >= screen.minY + bar.marginTop + bar.height + gaps.outer`** (bar inset invariant) for 1…12 windows on a 1512×982 screen and a 2560×1440 screen with non-zero origin; ratio clamping.

- [x] **P4.2 Accessibility permission service + onboarding**
  **Files:** `Sources/PersonaMode/Accessibility/AXPermission.swift`, `Sources/PersonaMode/App/AppState.swift` (axTrusted), `Sources/PersonaMode/Probes/ProbeAX.swift`.
  **Details:** `AXPermission.isTrusted` = `AXIsProcessTrusted()`; `request()` = `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)`; poll 1 s until trusted → publish `axTrustChanged` (modules hot-start). Onboarding UI: small floating `PersonaPanel` card ("Persona Mode needs Accessibility to tile windows") with *Open Settings* (`NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)`) and *Continue without tiling*. `--probe ax` prints `{trusted, bundleId, executablePath}`.
  **Verify:** after `make app` exists (P6.6 can be pulled forward — see note below) run `open -W -n "build/Persona Mode.app" --args --probe ax --out /tmp/ax.json && plutil -extract trusted raw -o - /tmp/ax.json` → `true` after granting; `false` before (and app must not crash). *Note:* if `build_app.sh` isn't done yet, implement **P6.6 now** (it has no dependencies on Phase 5/6 features).

- [x] **P4.3 AX private shims, window model, registry, float rules**
  **Files:** `Sources/PersonaMode/Accessibility/{AXPrivate,AXWorker,WindowRegistry,FloatRules}.swift`.
  **Details:** `AXPrivate`: `@_silgen_name("_AXUIElementGetWindow") func _AXUIElementGetWindow(_: AXUIElement, _: UnsafeMutablePointer<CGWindowID>) -> AXError` (wrap in `AXUIElement.windowID` returning `CGWindowID?`; fallback matches `kAXPositionAttribute/kAXSizeAttribute` + PID against `CGWindowListCopyWindowInfo` layer 0 windows). `AXWorker`: dedicated `Thread` running `CFRunLoopRun()`, `perform(_ block:)` + `performSync` helpers, `AXUIElementSetMessagingTimeout(systemWide, 0.25)`. `WindowRegistry`: for each `NSWorkspace.runningApplications` with `.regular` policy, `AXUIElementCreateApplication(pid)` → `kAXWindowsAttribute`; model `ManagedWindow { id: CGWindowID, pid, bundleId, element, frame, title, role, subrole, isMinimized, isFullscreen, isResizable, isTilable, spaceIndex? }`; AX attrs `kAXRoleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, "AXFullScreen", kAXTitleAttribute`; resizable via `AXUIElementIsAttributeSettable(kAXSizeAttribute/kAXPositionAttribute)`. `FloatRules.isTilable(_ w:, cfg:)` per §8.3.
  **Verify:** `open -W -n "build/Persona Mode.app" --args --probe windows-ax --out /tmp/wax.json` → JSON list; assert with `plutil -extract count raw -o - /tmp/wax.json` ≥ 1 when a Finder/Terminal window is open; confirm each entry has numeric `id` (non-null for ≥ 90 %) and `tilable` flags; windows of `dev.persona.mode` are never `tilable`.

- [x] **P4.4 AX observers & event stream**
  **Files:** `Sources/PersonaMode/Accessibility/AXWindowObserver.swift`, `Sources/PersonaMode/App/EventBus.swift`.
  **Details:** per-app `AXObserver` created with `AXObserverCreate(pid, callback, &obs)`; run-loop source added to `AXWorker`'s run loop; subscribe `kAXWindowCreatedNotification`, `kAXUIElementDestroyedNotification`, `kAXFocusedWindowChangedNotification`, `kAXMainWindowChangedNotification`, `kAXWindowMovedNotification`, `kAXWindowResizedNotification`, `kAXWindowMiniaturizedNotification`, `kAXWindowDeminiaturizedNotification`; app-level `NSWorkspace.didLaunchApplication/didTerminateApplication` (+ retry observer creation up to 5× at 200 ms for apps not ready). Emit `PersonaEvent` values to `EventBus` on main. Remove observers on app terminate and in the module-stop hook (**all `CFRunLoopRemoveSource` + `CFRelease`** on stop).
  **Verify:** `--probe ax-events --seconds 10` prints events as JSON lines while the tester opens/closes/moves a window; `V-BUILD`. (Manual stimulus; probe exits 0 and prints ≥ 1 event.)

- [x] **P4.5 Tiling controller**
  **Files:** `Sources/PersonaMode/Tiling/TilingController.swift`, `Sources/PersonaMode/Tiling/FrameJournal.swift`.
  **Details:** per §8.3. State per `(displayID, spaceIndex)`: ordered `[CGWindowID]`. `retile(display:)`: gather tilable windows on that display (window center in `ScreenModel.frame`, converted to AX coords), compute `LayoutEngine.layout` with `bar` = `BarInset(marginTop: cfg.topBar.marginTop, height: max(cfg.topBar.height, screen.safeTop))`, apply on `AXWorker` using `size → position → size`, read back & mark `constrained`. Debounce 60 ms; self-move suppression token; 150 ms drag-settle snap-back (`snapBackOnDrag`); `toggleFloat(focused)`; `tileNow` command; `setEnabled(false)` stops. `FrameJournal`: before the first tile of a window, record original frame in memory + `windows.json` (debounced 500 ms, in support dir); `restoreFrames(timeBudget: 1.0)` sets each existing window back (skip missing). Hook `restoreFrames` into `RestoreService` after critical restores (§9.6 step 5).
  **Verify:** `V-BUILD`; functional verification is P4.8.

- [x] **P4.6 Border geometry (Core) + renderer window**
  **Files:** `Sources/PersonaCore/Layout/BorderGeometry.swift`, `Sources/PersonaMode/Windows/BorderOverlayWindow.swift`, `Sources/PersonaSelfTest/Suites/LayoutSuite.swift` (extend).
  **Details:** `BorderGeometry.ringRect(windowFrameAX:, width:) -> CGRect` (outset by `width/2` so the stroke lies in the gap) and `clampedWidth(width, innerGap)`. `BorderOverlayWindow` (one per screen; level `.floating`, `ignoresMouseEvents=true`, transparent, `canJoinAllSpaces`): root layer-backed `NSView` with a `CAShapeLayer` (`strokeColor` cyan, `lineWidth`, `fillColor` clear, `shadowColor` cyan, `shadowRadius 10`, `shadowOpacity 0.9`, `shadowOffset .zero`), `path = CGPath(roundedRect:cornerWidth:cornerHeight:)`; update with `CATransaction.setDisableActions(true)` (instant) or a 90 ms `CABasicAnimation` on `path` for glide; pulse `CABasicAnimation(keyPath:"shadowOpacity")` autoreversing 2.4 s when `border.pulse`.
  **Verify:** `V-TEST layout` (ring rect math; width clamp); `swift run PersonaMode --probe render border /tmp/border.png --w 600 --h 400` (probe draws a ring around a dummy rect) — open PNG, glow visible.

- [x] **P4.7 Border controller (follow focus) + Spike S-4**
  **Files:** `Sources/PersonaMode/Border/BorderController.swift`, `docs/SPIKE_RESULTS.md`.
  **Details:** Subscribes to `focusChanged`, `frameChangedExternally`, `windowDestroyed`, `spaceChanged`. Resolves focused window frame in AX coords → converts to AppKit coords for the screen's window → updates ring. During an active drag/resize (moved/resized events within 200 ms) run a 60 Hz `Timer`/display-link polling **only** `CGWindowListCreateDescriptionFromArray([wid])` bounds; stop 250 ms after last event. Hide when: AX untrusted, focused app is Persona, window fullscreen/minimized, no focused window. **S-4:** try `borderWindow.order(.above, relativeTo: Int(targetWindowID))`; record in SPIKE_RESULTS whether it keeps z-order correct with overlapping windows; keep `.floating` fallback if unreliable.
  **Verify:** `V-BUILD`; manual run via bundle (P4.8). Probe `--probe border-state --seconds 5 --out f` prints `{visible, frame, targetWindowId}` while a window is focused.

- [x] **P4.8 Integration + automated tiling E2E**
  **Files:** `Sources/PersonaMode/App/LifecycleController.swift` (modify), `scripts/e2e_tiling.sh`.
  **Details:** Start `TilingController` and `BorderController` when AX trusted (and on `axTrustChanged`); register stop hooks; commands `tileNow`, `toggleFloatFocused` wired. `scripts/e2e_tiling.sh`: (1) require AX trust via `--probe ax`; (2) open 3 TextEdit windows (`osascript -e 'tell application "TextEdit" to make new document'` ×3); (3) launch the bundle in dry-run mode; (4) `PersonaMode --ctl tile`; sleep 1; (5) `--probe windows-ax` for TextEdit windows; (6) assert with `plutil -extract` + shell arithmetic: no pair overlaps; every `y ≥ barBottom + outerGap` (`barBottom = marginTop + height`); inner gaps == configured `inner` (±1 pt) between adjacent windows; (7) `--ctl quit`; (8) assert TextEdit windows' frames equal the original frames captured in step 2 (**frame restore works**, ±2 pt); (9) quit TextEdit without saving (`osascript … close every document saving no`).
  **Verify:** `V-BUILD && make app && bash scripts/e2e_tiling.sh` → `TILING E2E: PASS`. Manual: focus-follow glow looks right; dragging a window snaps back; `⌃⌥F` floats it.

### ✅ Phase 4 Gate
`swift run persona-selftest layout` green; `bash scripts/e2e_tiling.sh` green; S-4 recorded; with AX **denied** the app still launches, bar/HUD work, tiling/border disabled, quitting restores cleanly (test by `tccutil reset Accessibility dev.persona.mode`); `make verify-clean` green.

---

# PHASE 5 — Global Hotkeys & Floating Launcher (Rofi clone)

- [x] **P5.1 Fuzzy matcher (Core)**
  **Files:** `Sources/PersonaCore/Launcher/FuzzyMatcher.swift`, `Sources/PersonaSelfTest/Suites/FuzzySuite.swift`.
  **Details:** `FuzzyMatcher.score(query:, candidate:) -> (score: Int, matchedIndices: [Int])?` per §8.5 (case-insensitive subsequence; prefix +30; word boundary after space/`-`/`_`/`.` +12; camelCase +8; consecutive +8/char; gap −1/char; `nil` if not a subsequence). `rank(items:query:)` stable sort by score desc, then name.
  **Verify:** `V-TEST fuzzy` — golden: query `saf` ⇒ `Safari` before `Keychain Access`/`System Settings`; `term` ⇒ `Terminal` first; `vsc` ⇒ `Visual Studio Code`; `xyz` ⇒ no matches; empty query ⇒ all in original order; matched indices correct for highlight rendering.

- [x] **P5.2 App indexer**
  **Files:** `Sources/PersonaMode/Launcher/{AppIndexer,LauncherItem}.swift`.
  **Details:** scan the directories in §8.5 (depth ≤ 2, skip `*.app/Contents`), parse `Contents/Info.plist` via `Bundle(url:)`, skip `LSUIElement`/`LSBackgroundOnly` helper apps unless in `/System/Applications`; item `{id (bundle path), name, bundleId, url}`; icons lazy via `NSWorkspace.shared.icon(forFile:)` + `NSCache`. Refresh if any root directory `contentModificationDate` changed since last scan (checked on each launcher open; scan on a background queue; ≤ 300 ms for ~200 apps). `LauncherItem` enum `.app(AppEntry) | .action(ActionEntry)`; `ActionEntry` ids: `tile`, `toggleFloat`, `reloadTheme`, `toggleDarkHour`, `openTerminal`, `openVisualizer` (only if `cava` found), `exitPersona`.
  **Verify:** `swift run PersonaMode --probe apps --query saf --out /tmp/apps.json && plutil -extract count raw -o - /tmp/apps.json && plutil -extract results.0.name raw -o - /tmp/apps.json` → count > 10; first result `Safari`. Also `--query exit` → first result `Exit Persona Mode`.

- [x] **P5.3 Hotkey center (Carbon)**
  **Files:** `Sources/PersonaMode/Hotkeys/HotKeyCenter.swift`.
  **Details:** parse chords from config (`"opt+space"`, `"ctrl+opt+cmd+q"`, …) to `(keyCode, carbonModifiers)` using a static table (a–z, 0–9, space, return, escape, arrows); `RegisterEventHotKey(keyCode, mods, EventHotKeyID(signature: OSType("PRSN"), id: n), GetApplicationEventTarget(), 0, &ref)`; single `InstallEventHandler` for `kEventClassKeyboard/kEventHotKeyPressed` dispatching to `CommandRouter`. `registerAll() -> [String: OSStatus]` (failures surfaced in `AppState.hotkeyErrors`). `unregisterAll()` via `UnregisterEventHotKey` (called in restore hook). Panic chord → `CommandRouter.send(.panic)` handled **directly** by `RestoreService.restoreAll(.panic)` then `exit(0)`.
  **Verify:** `swift run PersonaMode --probe hotkeys --out /tmp/hk.json` (registers every configured chord, prints `{chord: status}`, unregisters, asserts `status == 0` — a non-zero for `opt+space` is acceptable *only* if another app owns it; report it) ; `V-BUILD`. **Manual:** `⌥Space` toggles launcher (P5.5).

- [x] **P5.4 Command router**
  **Files:** `Sources/PersonaMode/App/CommandRouter.swift`.
  **Details:** `enum PersonaCommand` (§7.1), `CommandRouter.send(_:)` on main; handlers injected: tiling, border, launcher, terminal, lifecycle. `exitPersona` → `NSApp.terminate(nil)`; `panic` → immediate restore + `exit(0)`; `reloadTheme` → re-load config, re-render profiles, rebuild windows (`WindowHostManager.rebuild()`), re-register hotkeys.
  **Verify:** `V-BUILD`.

- [x] **P5.5 Launcher panel UI**
  **Files:** `Sources/PersonaMode/UI/Launcher/{LauncherPanel,LauncherView,LauncherRow}.swift`, `Sources/PersonaMode/Launcher/LauncherController.swift`.
  **Details:** `LauncherPanel: PersonaPanel` with `canBecomeKey=true`, level `WindowLevels.launcher`, size 640×(56+8·52), centered at 38 % height of the screen under the mouse (`NSEvent.mouseLocation`). Content: `NSVisualEffectView` (`.hudWindow`, `.behindWindow`, `.active`, `maskImage` rounded) + SwiftUI overlay: midnight tint @ 55 %, cyan hairline `AngledPanel` frame, search field (`TextField` with `@FocusState`, placeholder `SEARCH ▸`, display font), result list (max 8 visible, scrolls), selected row = `SkewedPill` cyan fill with `midnight` text; matched characters highlighted. Key handling in a `NSEvent.addLocalMonitorForEvents(.keyDown)` while visible: `↑/↓`, `⌃J/⌃K`, `⌃N/⌃P`, `⏎`, `⌘⏎`, `Esc`, `⌘Q` (→ `exitPersona` confirmation-free), `⌘1…9` quick pick. `LauncherController.toggle()`; closes on `NSWindow.didResignKeyNotification`, after running an item, or Esc. Reset query on show. Fade/scale-in 120 ms (opacity + `transform.scale` 0.98→1).
  **Verify:** `swift run PersonaMode --probe render launcher /tmp/launcher.png --w 640 --h 472 --query saf` → open PNG: skewed highlight on first row, blur not required in offscreen. `swift run PersonaMode --probe launcher-open --out /tmp/lo.json` → `{level:100, canBecomeKey:true, visibleAfterShow:true, visibleAfterEsc:false}` (probe drives `LauncherController` directly with synthetic key input — no AX needed).

- [x] **P5.6 Item execution**
  **Files:** `Sources/PersonaMode/Launcher/LauncherController.swift` (extend).
  **Details:** apps: `NSWorkspace.shared.openApplication(at:configuration:)` (`configuration.activates = true`); `⌘⏎` → `NSWorkspace.shared.activateFileViewerSelecting([url])`; actions → `CommandRouter`. *Exit Persona Mode* row shows a red-tinted style and runs `exitPersona`.
  **Verify:** `swift run PersonaMode --probe launcher-run --item "app:com.apple.calculator"` launches Calculator (then `osascript -e 'tell application "Calculator" to quit'`); `--item "action:exitPersona"` returns exit code 0 and logs `restoreAll(userQuit)`.

- [x] **P5.7 `--ctl` channel + wiring everything in the lifecycle**
  **Files:** `Sources/PersonaMode/main.swift`, `Sources/PersonaMode/App/CommandRouter.swift`, `Sources/PersonaMode/App/LifecycleController.swift`.
  **Details:** `PersonaMode --ctl quit|reload|tile|panic|launcher` posts `DistributedNotificationCenter.default().postNotificationName(Notification.Name("dev.persona.mode.command"), object: nil, userInfo: ["cmd": …], deliverImmediately: true)` and exits 0 without creating `NSApplication`. The running app observes and maps to `PersonaCommand`. Lifecycle starts `HotKeyCenter` (registered/unregistered with the session).
  **Verify:** with the app running (dry-run, bundle): `"build/Persona Mode.app/Contents/MacOS/PersonaMode" --ctl tile; echo $?` → 0 and tiling happens (e2e_tiling covers it); `--ctl quit` terminates the app within 3 s (`pgrep -f "Persona Mode"` empty).

### ✅ Phase 5 Gate
`V-TEST fuzzy`; probes `apps`, `hotkeys`, `launcher-open` OK; manual: `⌥Space` opens launcher, typing filters, `Esc`/click-away closes, launching an app works, *Exit Persona Mode* quits and restores; `make verify-clean` green.

---

# PHASE 6 — Isolated Terminal/Fastfetch Profiles, Menu-Bar Controller, Packaging & End-to-End Polish

- [ ] **P6.1 Static terminal & CLI profiles**
  **Files:** `Resources/profiles/fastfetch/{config.jsonc,logo.txt}`, `Resources/profiles/ghostty/config`, `Resources/profiles/kitty/kitty.conf`, `Resources/profiles/wezterm/wezterm.lua`, `Resources/profiles/alacritty/alacritty.toml`, `Resources/profiles/terminal-app/Persona3Reload.terminal`, `Resources/profiles/cava/config`, `Sources/PersonaSelfTest/Suites/ThemeSuite.swift` (extend).
  **Details:** Palette (all files): background `#0a192f`, foreground `#e8f6ff`, cursor `#00d8ff`, selection `#1f6bff`, ANSI 0–7 = `#0a192f #ff3b5c #5dffcf #ffd24a #1f6bff #b48cff #00d8ff #e8f6ff`, bright variants lighter; font `Rajdhani`/`Menlo` fallback ("JetBrains Mono" if present is optional), window padding 14, opacity 0.92 (+blur where supported), window title "PERSONA // DARK HOUR". **fastfetch** `config.jsonc`: `logo: { "type": "file", "source": "{{PROFILE_DIR}}/fastfetch/logo.txt", "color": {"1":"#00d8ff","2":"#e8f6ff","3":"#1f6bff"} , "padding": {"left":2,"right":3}}`, `display.separator: "  ▸  "`, key/title colors cyan, modules: title, separator, os, host, kernel, uptime, packages, shell, terminal, cpu, gpu, memory, disk, battery, localip, `{ "type":"custom","format":"◈ DARK HOUR · MEMENTO MORI"}`, colors. `logo.txt`: **original** ASCII art ≤ 36×18 (crescent moon over hourglass) using `$1/$2/$3` color placeholders. `Persona3Reload.terminal`: XML plist (`name`="Persona 3 Reload", `type`="Window Settings", `BackgroundColor`, `TextColor`, `CursorColor`, `ANSI*Color` as `NSKeyedArchiver`-encoded NSColor data — generate via a small Swift probe `--probe gen-terminal-profile` that writes the file using `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:false)`). `cava/config`: `[color] gradient=1`, gradient_color_1..N from cyan→azure→ice, `[output] method=ncurses`.
  Selftest: parse hex colors out of each text profile (regex) and assert every `#rrggbb` found is in the `ThemeTokens` palette ∪ the declared ANSI list (no drift).
  **Verify:** `V-TEST theme`; `fastfetch -c Resources/profiles/fastfetch/config.jsonc --logo-source Resources/profiles/fastfetch/logo.txt 2>&1 | head -30` renders colored art + modules (with the `{{PROFILE_DIR}}` placeholder temporarily replaced by `$PWD/Resources/profiles` via `sed` into `/tmp/ff.jsonc`); `plutil -lint Resources/profiles/terminal-app/Persona3Reload.terminal` → `OK`.

- [ ] **P6.2 Profile renderer (temp dir, ledgered)**
  **Files:** `Sources/PersonaMode/Terminal/ProfileRenderer.swift`.
  **Details:** copy `Resources/profiles/**` → `$TMPDIR/PersonaMode/profiles/` (0700), substituting `{{PROFILE_DIR}}` → that absolute path in text files; first `SystemMutator.apply(.tempDir(path))` (**write-ahead before creating the dir**); `cleanup()` in restore hook (prefix-guarded). Re-render on `reloadTheme`.
  **Verify:** `PERSONA_DRY_RUN=1 swift run PersonaMode --probe profiles --out /tmp/pr.json && ls "$(plutil -extract dir raw -o - /tmp/pr.json)"` shows the rendered tree; `grep -r '{{PROFILE_DIR}}' "$(plutil -extract dir raw -o - /tmp/pr.json)"` → no matches; after probe exit the dir is gone.

- [ ] **P6.3 Terminal launcher + Terminal.app fallback + Spike S-6**
  **Files:** `Sources/PersonaMode/Terminal/{TerminalLauncher,TerminalAppProfile}.swift`, `docs/SPIKE_RESULTS.md`.
  **Details:** detection (`NSWorkspace.urlForApplication(withBundleIdentifier:)`: `com.mitchellh.ghostty`, `net.kovidgoyal.kitty`, `com.github.wez.wezterm`, `org.alacritty`, plus binaries on `PATH`/`/opt/homebrew/bin`) per `terminal.preference`; build the command per §8.6 table; shell payload `fastfetch -c <tmp>/fastfetch/config.jsonc; exec "$SHELL" -l` (omit fastfetch if not installed → show hint row in launcher). Environment passed to the terminal process only (`PERSONA_MODE=1`); **no `XDG_CONFIG_HOME` override**. **Terminal.app path:** write payload as `<tmp>/run.command` (chmod +x) that prints fastfetch then `exec "$SHELL" -l`; first `SystemMutator.apply(.terminalProfile("Persona 3 Reload"))` (write-ahead) → `open <tmp>/terminal-app/Persona3Reload.terminal` (imports + opens profile window) → then run command via AppleScript `tell application "Terminal" to do script "…" in window 1` using settings set `"Persona 3 Reload"`. **S-6:** determine the most reliable profile removal: (a) AppleScript `tell application "Terminal" to delete settings set "Persona 3 Reload"` (only if Terminal already running — otherwise skip launching), (b) `PlistBuddy -c "Delete :'Window Settings':'Persona 3 Reload'" ~/Library/Preferences/com.apple.Terminal.plist` + `killall cfprefsd` (careful: only affects that key). Record the winner; implement in restore (`RestoreService` terminal cleanup) and mirror in `restore_macos.sh`.
  **Verify:** `swift run PersonaMode --probe terminal-detect --out /tmp/td.json && plutil -extract chosen raw -o - /tmp/td.json` → `terminal` on this machine (no Ghostty/kitty). **Manual (⚠ touches Terminal.app prefs, ledgered):** launch via bundle, choose *Open Terminal (P3R)* → themed window with fastfetch; quit app → `defaults read com.apple.Terminal "Window Settings" | grep -c "Persona 3 Reload"` → `0`.

- [ ] **P6.4 Menu-bar status item + main menu**
  **Files:** `Sources/PersonaMode/StatusItem/StatusItemController.swift`, `Sources/PersonaMode/App/MainMenu.swift` (extend).
  **Details:** `NSStatusBar.system.statusItem(withLength: .variableLength)` with template image drawn from a Path (crescent), menu: *Persona Mode — ACTIVE* (disabled header), *Tile Windows*, *Toggle Tiling*, *Toggle Active Border*, *Toggle Dark Hour*, *Reload Theme*, *Open Terminal (P3R)*, separator, status lines (*Accessibility: Granted/Not granted → Open Settings*, hotkey registration errors), **Return to macOS (Quit) ⌘Q**. Item lives in the native menu bar → visible on hover when the native bar is auto-hidden (§ADR-6). Removed in restore hook (`NSStatusBar.system.removeStatusItem`).
  **Verify:** `V-BUILD`; manual via bundle: icon visible, every item works; `osascript -e 'tell application "Persona Mode" to quit'` → full restore.

- [ ] **P6.5 Config hot-reload**
  **Files:** `Sources/PersonaMode/App/ConfigWatcher.swift`.
  **Details:** `DispatchSource.makeFileSystemObjectSource` on `~/Library/Application Support/PersonaMode/config.json` (watch the *directory* so create/replace is caught; debounce 250 ms); on change → `AppConfig.load` → `CommandRouter.send(.reloadTheme)`; invalid ⇒ keep old config, `AppState.configWarnings` shown in status menu. **Never creates the file** (I8).
  **Verify:** with app running: `echo '{"border":{"width":5}}' > "$HOME/Library/Application Support/PersonaMode/config.json"` → within 1 s `--probe border-state` shows width 5; then `rm` the file (user-owned test artifact) and confirm revert to default.

- [ ] **P6.6 Packaging: `build_app.sh`, Info.plist, signing, uninstall**
  **Files:** `scripts/{build_app.sh,setup_signing.sh,run_dev.sh,uninstall.sh}`, `Resources/Info.plist.template`, `Makefile`, `docs/PERMISSIONS.md`.
  **Details:** `build_app.sh`: `swift build -c release`; `BIN="$(swift build -c release --show-bin-path)/PersonaMode"`; create `build/Persona Mode.app/Contents/{MacOS,Resources}`; copy binary → `Contents/MacOS/PersonaMode`; copy `Resources/fonts`, `Resources/profiles`, `scripts/{restore_macos.sh,guardian.sh}` → `Contents/Resources/{fonts,profiles,scripts}`; render `Info.plist` from template (`CFBundleIdentifier=dev.persona.mode`, `CFBundleName="Persona Mode"`, `CFBundleExecutable=PersonaMode`, `LSUIElement=true`, `LSMinimumSystemVersion=14.0`, `LSMultipleInstancesProhibited=true`, `NSAppleEventsUsageDescription="Persona Mode uses System Events to hide/restore the Dock and Menu Bar and reads Music/Spotify state."`, `NSHighResolutionCapable=true`, `CFBundleVersion`); `plutil -lint`; sign `codesign --force --deep --options runtime --sign "$IDENTITY" --identifier dev.persona.mode` where `IDENTITY` = `PersonaMode Dev` if present (`security find-identity -v -p codesigning`) else `-` with a loud warning about TCC churn; `codesign --verify --deep --strict`. `setup_signing.sh`: creates a self-signed *Code Signing* certificate "PersonaMode Dev" (openssl req/x509 with `extendedKeyUsage=codeSigning`, `security import … -k login.keychain -T /usr/bin/codesign`, trust setting prompt explained) — idempotent, optional, prints manual fallback instructions (Keychain Access → Certificate Assistant). `uninstall.sh`: `tccutil reset Accessibility dev.persona.mode`, `tccutil reset AppleEvents dev.persona.mode`, remove `build/`, run `restore_macos.sh --force-defaults` **only if** a stale state exists. `docs/PERMISSIONS.md`: how to grant/reset. Resource lookup in the app: `Bundle.main.resourceURL` → fonts/profiles/scripts.
  **Verify:**
  ```bash
  make app && plutil -lint "build/Persona Mode.app/Contents/Info.plist" && codesign --verify --deep --strict "build/Persona Mode.app" && echo SIGNED
  ls "build/Persona Mode.app/Contents/Resources" ; open -W -n "build/Persona Mode.app" --args --probe fonts --out /tmp/f.json && cat /tmp/f.json
  ```
  Expected: fonts probe `true/true` from the bundle (proves resource lookup without `Bundle.module`).

- [ ] **P6.7 Zero-trace E2E audit across *every* exit path (full)**
  **Files:** `scripts/verify_clean_state.sh` (extend to `--all`).
  **Details:** drive the **bundled** app (real mutations, real state dir, self-healing `trap`). Fingerprint = Phase-1 fingerprint **plus**: Terminal.app settings sets, per-screen wallpaper, `ls ~/Library/Application\ Support/PersonaMode`, `$TMPDIR/PersonaMode`, `pgrep -fl 'Persona Mode|guardian.sh'`, window count of dev.persona.mode (via `--probe`-less `CGWindowList` AppleScript/JXA), and a **residue scan**: `find ~/Library ~/.config -newer "$MARKER" \( -path '*/Caches/*' -o -path '*/Logs/*' -o -path '*TCC*' -o -path '*com.apple.LaunchServices*' -o -path '*/Saved Application State/*' \) -prune -o -type f -print` must list **nothing under PersonaMode** and nothing in `~/.config`. Scenarios (each `PASS/FAIL`): (1) `osascript -e 'tell application "Persona Mode" to quit'` (same Apple event as ⌘Q), (2) `--ctl quit`, (3) `--ctl panic`, (4) SIGINT, (5) SIGTERM, (6) SIGHUP, (7) SIGKILL (guardian), (8) SIGSTOP hang (guardian, `PERSONA_HANG_SECONDS=4`), (9) crash: `PersonaMode --crash-test` hidden flag that `fatalError()`s after activation (guardian), (10) stale-state relaunch recovery, (11) AX-denied launch + quit, (12) Terminal.app profile launched then quit.
  **Verify:** `make verify-clean` → `SCENARIO 1…12: PASS` and `ZERO-TRACE AUDIT: PASS`; the script prints the allowed-residue list from §9.9 (TCC only).

- [ ] **P6.8 Polish, soak & docs**
  **Files:** `README.md`, `docs/TRACE_LEDGER.md`, `docs/SPIKE_RESULTS.md`, `ARCHITECTURE.md` (reconcile with spike outcomes).
  **Details:** Display-change soak (plug/unplug or `NSApplication.didChangeScreenParametersNotification` simulation via System Settings → Displays resolution change); sleep/wake; Space switching; fullscreen apps (bar hidden, tiling skips fullscreen); Stage Manager behavior note; low-power mode pauses animation. Confirm perf budgets (`scripts/perf_check.sh 120` on the real bundle). README: install/build/run/quit/panic instructions (**prominently: panic = `⌃⌥⌘Q` or `scripts/restore_macos.sh`**), permissions, uninstall, fan-project disclaimer (§15). `docs/TRACE_LEDGER.md` copies §9.9 with measured reality. Update `ARCHITECTURE.md` wherever a spike changed a decision.
  **Verify:** `make doctor && V-BUILD && swift run persona-selftest && make app && bash scripts/perf_check.sh 120 && make verify-clean` all green; README commands copy-paste work on a clean clone (`git clone . /tmp/pm && cd /tmp/pm && make app`).

### ✅ Phase 6 / Release Gate
All gates green; `make verify-clean` PASS ×12; no `TODO`/`FIXME` left without an issue note in README "Known limitations"; known limitations documented: TCC grants persist; Terminal.app fallback profile is best-effort removed; Now-Playing limited to Music/Spotify; Spaces switching needs user-enabled shortcuts.

---

## Appendix A — Quick reference: probes & scripts

| Command | Purpose |
|---------|---------|
| `swift run persona-selftest [suite…]` | Pure-logic tests (`config state ledger mutator restore layout fuzzy theme telemetry coords`) |
| `swift run PersonaMode --probe snapshot` | Read-only system snapshot JSON |
| `--probe windows` | Level/click-through audit of own windows |
| `--probe render <shapes\|topbar\|hud\|wallpaper\|launcher\|border> out.png` | Offscreen SwiftUI render to PNG |
| `--probe telemetry / focus / spaces / nowplaying / fonts` | Data-source checks |
| `--probe ax / windows-ax / ax-events / border-state` | Accessibility checks (run via bundle) |
| `--probe apps / hotkeys / launcher-open / launcher-run / terminal-detect / profiles` | Launcher & terminal checks |
| `PersonaMode --ctl quit\|reload\|tile\|panic\|launcher` | Control the running app |
| `scripts/restore_macos.sh [--dry-run] [--force-defaults]` | **Panic button** |
| `scripts/guardian.sh` | Watchdog (spawned by app) |
| `scripts/verify_clean_state.sh [--phase 1\|--all]` | Zero-trace E2E |
| `scripts/e2e_tiling.sh` | Tiling E2E |
| `scripts/perf_check.sh [sec]` | CPU/RSS budget check |

## Appendix B — Dependency graph (what may be parallelized by a human; the agent should stay sequential)
`P1.* → P2.* → P3.1,3.2 → (P3.3–P3.5 independent) → P3.6 → P3.7 → P3.8 → P3.9 → P4.1 (pure; can run early) → P6.6 (pulled forward for AX probes) → P4.2 … P4.8 → P5.* → P6.1 … P6.5 → P6.7 → P6.8`.
