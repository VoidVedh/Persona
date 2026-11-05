# Spike Results & Platform Decisions

This document records the empirical results of technical spikes on macOS 26.6.2 (Tahoe) arm64, driving the architecture and restoration decisions.

---

## S-1 — Live Dock & Menu Bar Auto-Hide Mechanisms on macOS 26

### Objective
Determine empirically whether Dock and Menu Bar auto-hide can be toggled live without logout or restart, what underlying preferences are touched, and how to reliably restore stock state to pristine (absent-key) conditions.

### Experiments & Observations

1. **Menu Bar Autohide via System Events:**
   - Command: `osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to true'`
   - **Observed Behavior:** The native menu bar auto-hides immediately (no logout or reboot required).
   - **Preference Mutation:** This operation modifies `NSGlobalDomain _HIHideMenuBar` to `1` (or `true`).
   - `get autohide menu bar of dock preferences` returns `true`.
   - Reverting via AppleScript `tell application "System Events" to set autohide menu bar of dock preferences to false` sets the menu bar back to visible immediately and writes `0` (or `false`).
   - Running `defaults delete NSGlobalDomain _HIHideMenuBar` cleanly removes the key, restoring macOS to its pristine absent-key state while keeping the menu bar visible.

2. **Dock Autohide via System Events:**
   - Command: `osascript -e 'tell application "System Events" to set autohide of dock preferences to true'`
   - **Observed Behavior:** The Dock hides immediately with a smooth slide transition. No `killall Dock` is required.
   - **Preference Mutation:** `defaults read com.apple.dock autohide` changes from absent to `1`.
   - `get autohide of dock preferences` returns `true`.
   - Reverting via `tell application "System Events" to set autohide of dock preferences to false` returns the Dock to visible immediately and writes `0`.
   - Running `defaults delete com.apple.dock autohide` removes the preference key. The Dock remains visible because macOS defaults to visible when absent.

3. **Fallback Mechanism:**
   - If System Events / AppleScript is unavailable (e.g. Automation permission denied or system events hung), the fallback path is:
     - `defaults write com.apple.dock autohide -bool <val> && killall Dock`
     - `defaults write NSGlobalDomain _HIHideMenuBar -bool <val>`

### Decisions

- **Decision (Menu Bar Mechanism):** Use `systemEvents` (`tell application "System Events" to set autohide menu bar of dock preferences to ...`) as the primary mechanism for Menu Bar auto-hiding. Reconcile raw keys (`_HIHideMenuBar` and `AppleMenuBarVisibleInFullscreen`) during restoration by deleting keys that were originally absent.
- **Decision (Dock Mechanism):** Use `systemEvents` (`tell application "System Events" to set autohide of dock preferences to ...`) as the primary live mechanism. During restoration, if originally absent, set to `false` via System Events and then delete `com.apple.dock autohide`.
- **Decision (Fallback):** In headless or error scenarios where AppleScript times out or fails, fall back to `defaults write/delete` + `killall Dock`.
- **Decision (Zero-Trace Invariant):** Both keys default to "absent" on fresh macOS installations. The restoration sequence explicitly deletes both keys if they were absent in the snapshot, leaving no traces behind.

---

## S-2 / S-5 — Window levels, behaviors & hosting transparency on macOS 26 (Tahoe)

Measured with `PERSONA_DRY_RUN=1 swift run PersonaMode --probe windows --seconds 2` on a notched built-in display
(frame 1710×1112 in the current scaled mode, `safeAreaInsets.top = 38`).

| Check | Result |
|-------|--------|
| (1) Bar WindowServer layer == `.statusBar` (25) | **PASS** — `windows.0.layer = 25` |
| (1) Overlay layer == `desktopIconWindow − 1` | **PASS** — `-2147483604` (`desktopIconWindow = -2147483603`) |
| Bar `ignoresMouseEvents=false`, `canBecomeKey=false` | **PASS** |
| Overlay `ignoresMouseEvents=true` (hard-locked in `DesktopOverlayWindow`) | **PASS** (probe + selftest) |
| (4) Bar height on the notched display | **PASS** — probe reports bar height 38 (= safe inset > config 34) |
| Teardown: zero windows on screen after `stop()` | **PASS** — `windowsAfterStop = 0` (`windowsListedAfterStop = 2` are closed windows `.optionAll` still lists until the WindowServer reaps them) |
| `scripts/smoke_gui.sh` (GUI dry run: 2 windows on screen at layers `[-2147483604, 25]`, none after SIGTERM, state dir empty) | **PASS** |
| (2) Hover top edge reveals native menu bar above our bar | **NOT VERIFIED (manual)** — see decision below |
| (3) Full-screen app hides the bar | **NOT VERIFIED (manual)** — see decision below |
| (5) Clicks on desktop icons pass through the overlay | **NOT VERIFIED (manual)** — enforced by `ignoresMouseEvents` lock + selftest |
| (6) S-5 transparency: SwiftUI placeholder renders without a black box | **NOT VERIFIED visually** — hosting view layer is clear, window non-opaque, `sizingOptions=[]`; confirm by eye |

### Decisions

- **Decision (Bar level):** the project owner specified `level = .statusBar` (25) and
  `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`.
  Both are now the defaults (`topBar.level = "statusBar"`); `"mainMenuMinusOne"` remains selectable in config.
  This supersedes ADR-6's default. **Consequence:** at level 25 the bar sits *above* the native menu bar, so while
  the native menu bar is not auto-hidden the bar covers most of it (a 6 pt strip stays visible) and, because of
  `.fullScreenAuxiliary`, it also stays visible over full-screen apps. Escape hatches that never depend on the
  menu bar: the bar's **QUIT** button, `SIGTERM`/`SIGINT`, the guardian, and `scripts/restore_macos.sh`.
  S-1 showed the native menu bar can be auto-hidden live, which is the intended pairing for this level.
- **Decision (Module split):** window/UI/telemetry code lives in a new library target `PersonaKit` so
  `persona-selftest` can import it and assert on real `NSWindow` configuration (an executable target cannot be
  imported). `PersonaMode` keeps `main.swift`, lifecycle, system adapters and probes.

---

## S-3 — Private CoreGraphics Space Enumeration (`CGSCopyManagedDisplaySpaces`) on macOS 26

### Objective
Determine whether `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, and `CGSGetActiveSpace` resolve via `dlsym(RTLD_DEFAULT, ...)` on macOS 26.6.2 (Tahoe) and provide reliable workspace indices.

### Observations & Decisions
- All three symbols resolve cleanly via `dlsym` at runtime on macOS 26.6.2 (`--probe spaces` reports `available: true`, `count: 1`, `active: 1`).
- **Decision:** Resolve symbols dynamically via `dlsym(RTLD_DEFAULT, ...)` so the binary never hard-links private SPIs, and fall back to a single active workspace pill (`[SpaceInfo(index: 1, isActive: true)]`) if unavailable.

---

## S-4 — Active-Window Border Overlay Level & Z-Order on macOS 26

### Objective
Evaluate relative window ordering (`order(.above, relativeTo:)`) vs `.floating` window level (`NSWindow.Level.floating`) for the active-window glowing border overlay.

### Observations & Decisions
- `BorderOverlayWindow` configured with `level = .floating`, `ignoresMouseEvents = true` (hard-locked), `isOpaque = false`, `backgroundColor = .clear`, and `hasShadow = false` renders cleanly above the active application window while remaining below the Persona Top Bar (`.statusBar` = 25) and the Floating Launcher (`popUpMenu - 1` = 100).
- Setting `shapeLayer.shadowPath = newPath` alongside `shapeLayer.path = newPath` allows the WindowServer (`CARenderServer`) to composite the cyan outer glow in hardware with zero offscreen CPU rasterization overhead.
- When `AXIsProcessTrusted()` is `false`, `SystemAXWindowProvider` gracefully falls back to `CGWindowListCopyWindowInfo` (normal layer `kCGWindowLayer == 0`) so the border tracker still follows the frontmost window without crashing or prompting.

---

## S-6 — Terminal.app Settings Set Removal & Zero-Dotfile Rice Isolation

### Objective
Determine the most reliable method to clean up the temporary `"Persona 3 Reload"` profile imported into macOS `Terminal.app` when used as the fallback terminal, without popping up `Terminal.app` if it is already closed.

### Observations & Decisions
1. **Isolated Configs (`$TMPDIR/PersonaMode/profiles/`):**
   - `ProfileRenderer` copies `Resources/profiles/**` into `$TMPDIR/PersonaMode/profiles/` (mode `0700`) and substitutes `{{PROFILE_DIR}}` with the temporary directory's absolute path.
   - `Ghostty`, `kitty`, `WezTerm`, and `Alacritty` accept explicit `--config-file` / `--config` CLI arguments pointing into `$TMPDIR/PersonaMode/profiles`, leaving zero residue in `~/.config` or `~/.zshrc`.
2. **Terminal.app Fallback Cleanup:**
   - Calling AppleScript `tell application "Terminal" ...` when `Terminal.app` is not running causes macOS to launch `Terminal.app`.
   - **Decision:** Check `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal")`. Only run `delete (every settings set whose name is "Persona 3 Reload")` via AppleScript when `Terminal.app` is already running; in all cases, delete `:'Window Settings':'Persona 3 Reload'` from `~/Library/Preferences/com.apple.Terminal.plist` via `/usr/libexec/PlistBuddy` followed by `CFPreferencesAppSynchronize("com.apple.Terminal")`. Mirror the `PlistBuddy` cleanup in `scripts/restore_macos.sh`.

---

## S-V2-1 — Transparent `WKWebView` on macOS 26.6.2 (Tahoe) arm64

### Objective
Empirically verify whether `WKWebView` renders with a transparent background (`alpha == 0` at un-painted corners) over a borderless non-opaque `NSWindow` (`isOpaque = false`, `backgroundColor = .clear`) on macOS 26.6.2 (`MacOSX27.0.sdk`).

### Experiments & Observations
- Command: `swift run PersonaMode --probe web-transparency`
- Output:
  ```json
  {
    "alphaAtCorner" : 0,
    "chosen" : "drawsBackground=false + underPageBackgroundColor=.clear + nonOpaqueNSWindow",
    "drawsBackgroundKVC" : true,
    "underPage" : false
  }
  ```
- Setting `webView.setValue(false, forKey: "drawsBackground")` + `webView.underPageBackgroundColor = .clear` inside a borderless `NSWindow` with `isOpaque = false, backgroundColor = .clear` yields `alphaAtCorner = 0.0` (`0%` opacity at unpainted corners).
- **Decision:** Use `drawsBackground = false` + `underPageBackgroundColor = .clear` in `WebSurfaceView`, backed by `WebTransparencyCheck.passes()` at startup with automatic fallback to `PersonaContentFactory` (SwiftUI) if a future macOS build breaks KVC transparency (ADR-V2-9).

---

## S-V2-2 — Deterministic Headless `WKWebView` Snapshot (`--probe render webui`) & `png-stats`

### Objective
Determine a reliable off-screen capture strategy for `WKWebView` without requiring Screen Recording permissions (`CGWindowListCreateImage` / `screencapture`), preserving full 8-bit alpha channel and bundled `@font-face` typography.

### Experiments & Observations
- **Winning Capture Strategy (R-V2-2 option b):** Host `WebSurfaceView` inside a borderless non-opaque `NSWindow` with `alphaValue = 0.02`, `ignoresMouseEvents = true`, ordered front while pumping `RunLoop.main` until `document.documentElement.dataset.ready === '1'` (set after `document.fonts.load(...)` for `"Bebas Neue"` and `"Rajdhani"` + animation freeze at `?freeze=<ms>&seed=<n>`).
- Call `WKWebView.takeSnapshot(with: WKSnapshotConfiguration)` where `snapshotWidth = (width * scale) / win.backingScaleFactor` so `--w W --h H --scale 2` deterministically emits exact `2W × 2H` pixel PNGs on Retina displays.
- **CSP Finding:** Because `WebUIRouter` enforces `script-src 'self' persona:` (no `'unsafe-inline'`), HTML files must not use inline `<script>` blocks; `bridge.js` auto-boots via `<body data-surface="..." data-fixture="..." data-autoboot="1">`.
- Verified with `--probe render webui shapes /tmp/v2_shapes.png --w 900 --h 520 --scale 2 --freeze 0` + `--probe png-stats /tmp/v2_shapes.png`:
  - `1800x1040 px`, `cornerAlphaPct = [0, 0, 0, 0]`, `alphaCoveragePct = 92.79%`, `cyanPct = 2.67%`, `whitePct = 8.93%`, `navyPct = 85.01%`.

---

## S-V2-3 — Packaged `.app` Font Registration, WebKit Helper Cost & Zero-Trace Residue Scan

### Objective
1. Verify `CTFontManagerRegisterFontsForURL` registers `Bebas Neue` and `Rajdhani` when launched from the signed `build/Persona Mode.app` bundle (`open -W -n "build/Persona Mode.app" --args --probe fonts`).
2. Measure combined idle CPU and RSS of `PersonaMode` + its spawned `com.apple.WebKit.*` helper processes (`WebContent`, `GPU`, `Networking`).
3. Verify whether `WKWebsiteDataStore.nonPersistent()` leaves any directories under `~/Library/{WebKit,Caches,HTTPStorages,Saved Application State}/dev.persona.mode*`.

### Experiments & Observations
1. **Packaged `.app` Font Probe:**
   - Note on codesigning in `~/Desktop`: macOS FileProvider attaches `com.apple.FinderInfo` / `com.apple.fileprovider.fpfs#P` to `.app` directories created inside `~/Desktop`, which causes `codesign --deep --strict` to fail with `resource fork, Finder information, or similar detritus not allowed`. `scripts/build_app.sh` now stages and signs `Persona Mode.app` inside `$TMPDIR` and copies the verified bundle to `build/Persona Mode.app` via `ditto`.
   - `open -W -n "build/Persona Mode.app" --args --probe fonts --out /tmp/f.json` returned:
     ```json
     { "bebas" : true, "rajdhani" : true }
     ```
2. **Baseline WebKit Helper CPU & Memory (`scripts/perf_check.sh`):**
   - App process + 4 WebKit helper processes (`WebContent`, `GPU`, `Networking`):
     - `app`: avg CPU = `0.10%`, max RSS = `87.69 MB`
     - `webkit helpers (4)`: avg CPU = `0.16%`, max RSS = `106.11 MB`
     - `total`: avg CPU = `0.26%` (well within `≤ 10.0%` budget), max RSS = `193.78 MB` (well within `≤ 500.0 MB` budget).
3. **WebKit Zero-Trace Residue:**
   - Despite `WKWebsiteDataStore.nonPersistent()`, WebKit can occasionally create empty bundle-scoped cache directories on teardown on macOS 26. `WebCacheCleaner.cleanup()` (in `PersonaKit`) and `scripts/restore_macos.sh` explicitly purge the exact bundle-scoped paths (`~/Library/WebKit/dev.persona.mode`, `~/Library/Caches/dev.persona.mode`, `~/Library/HTTPStorages/dev.persona.mode*`, `~/Library/Saved Application State/dev.persona.mode.savedState`).
   - Post-exit verification confirmed both `~/Library/WebKit/dev.persona.mode` and `~/Library/Caches/dev.persona.mode` are completely absent (`No such file or directory`).

