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
