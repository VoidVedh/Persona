# Persona Mode (`dev.persona.mode`)

> A toggleable, zero-trace macOS desktop environment inspired by the **Persona 3 Reload** Linux Hyprland rice aesthetic — built natively in Swift with AppKit, SwiftUI, CoreAnimation, Carbon, and the macOS Accessibility API.

---

## Key Features

- **Zero-Trace Toggleability & Crash-Safe Recovery (Phase 1):**
  - Write-ahead transactional mutation ledger (`state.json` + `.prev` backup) tracks Dock autohide, native Menu Bar visibility, wallpaper state, and tiled window frames (`windows.json`).
  - Out-of-process **Guardian Watchdog** monitors heartbeat liveness and automatically restores stock macOS state within seconds if the process is killed (`SIGKILL` / `kill -9`) or hung (`SIGSTOP`).
  - Exiting (`Cmd+Q`, Top Bar `QUIT`, Launcher `Exit Persona Mode`, or `Ctrl+Opt+Cmd+Q` Panic) restores 100% of original macOS settings and window frames with zero leftover processes or files.

- **Persona 3 Reload Design System & Multi-Display Window Host (Phase 2):**
  - Custom geometric vector primitives (`AngledPanel`, `SkewedPill`, `TriangleTick`, `HexRing`, `Halftone`) in the signature P3R palette (`abyss`, `midnight`, `cyan`, `azure`, `ice`, `darkHour`).
  - Multi-display and Apple Silicon notch-aware coordinate engine (`CoordinateSpace`) converting seamlessly between AppKit (bottom-left) and Quartz/Accessibility (top-left) coordinates.

- **Waybar-Style Top Status Bar & Desktop HUD (Phase 3):**
  - **Top Bar (`TopBarPanel`):** Notch-aware bar at `statusBar` window level featuring skewed workspace pills (1–5), active app & window title tracking, live system telemetry (`CPU`, `RAM`, `Battery`, `Wi-Fi` RSSI bars, `Volume`), two-line clock badge, and quick `QUIT` pill.
  - **Desktop HUD (`DesktopOverlayWindow`):** Click-through desktop overlay at `desktopIcon - 1` featuring the Dark Hour crescent moon, rotating `HexRing` ambient accents, `DateTimeWidget` with automatic **Dark Hour (`00:00–00:59`)** emerald theme shift, and event-driven **Now Playing** widget (Apple Music & Spotify).

- **Active-Window Glow Border & Tiling Engine (Phase 4):**
  - **Active-Window Border (`BorderOverlayWindow` / `BorderController`):** Click-through (`ignoresMouseEvents = true`) hardware-rasterized cyan glow ring that tracks the focused window with 16ms coalesced frame updates and graceful `CGWindowListCopyWindowInfo` fallback when Accessibility is untrusted.
  - **Window Tiling Engine (`LayoutEngine` / `TilingController`):** Deterministic **Dwindle (BSP)** and **Master-Stack** layouts reserving the `38pt` Top Bar inset plus configurable outer/inner gaps, drag snap-back, per-window float toggle, and original frame restoration via `FrameJournal`.

- **Global Hotkeys & Floating P3R App Launcher (Phase 5):**
  - **Carbon Hotkey Center (`HotKeyCenter`):** System-wide shortcuts registered via Carbon `RegisterEventHotKey` and automatically unregistered on exit.
  - **Floating Launcher (`LauncherPanel` / `LauncherController`):** P3R-styled floating panel with subsequence `FuzzyMatcher` scoring across `/Applications` and `/System/Applications`, built-in quick commands (`Tile Windows`, `Retile`, `Toggle Float`, `Reload Theme`, `Toggle Dark Hour`, `Open Terminal (P3R)`, `Exit Persona Mode`), keyboard navigation (`↑`/`↓`, `⌃J`/`⌃K`, `⏎`, `⌘⏎`, `⌘1…9`, `Esc`), and automatic dismissal on focus loss.

---

## Default Hotkeys

| Shortcut | Action |
| :--- | :--- |
| `Opt + Space` (`⌥Space`) | Toggle Floating P3R App Launcher |
| `Ctrl + Opt + T` (`⌃⌥T`) | Tile / Retile Windows on Active Screen |
| `Ctrl + Opt + F` (`⌃⌥F`) | Float / Unfloat Focused Window |
| `Ctrl + Opt + R` (`⌃⌥R`) | Reload `config.json` & Refresh Theme |
| `Ctrl + Opt + Cmd + Q` (`⌃⌥⌘Q`) | **Panic Exit** — Immediate Zero-Trace Restore |

---

## Build, Verification & CLI Usage

### Build & Self-Test Suite
Compiles cleanly with macOS CommandLineTools (`swift build`, zero Swift macro dependencies):

```bash
# Check toolchain & environment
make doctor

# Build all targets (PersonaCore, PersonaKit, PersonaMode, persona-selftest)
swift build

# Run all 12 deterministic self-test suites (986 assertions)
swift run persona-selftest
```

### Verification & Performance Gates
```bash
# Verify 6 zero-trace crash/hang/recovery scenarios (SIGINT, SIGTERM, kill -9, kill -STOP, stale state)
make verify-clean

# Verify window tiling & frame restoration E2E
bash scripts/e2e_tiling.sh

# Verify GUI window layering & lifecycle smoke check
bash scripts/smoke_gui.sh

# Verify idle CPU (<= 4.0%) and RSS memory (<= 150 MB) budget
bash scripts/perf_check.sh 6
```

### Remote Control (`--ctl`) & Diagnostic Probes (`--probe`)
```bash
# Control a running Persona Mode session
swift run PersonaMode --ctl tile
swift run PersonaMode --ctl launcher
swift run PersonaMode --ctl reload
swift run PersonaMode --ctl quit

# Render headless offscreen PNG previews
swift run PersonaMode --probe render topbar /tmp/topbar.png
swift run PersonaMode --probe render hud /tmp/hud.png
swift run PersonaMode --probe render border /tmp/border.png
swift run PersonaMode --probe render launcher /tmp/launcher.png
```

---

## Panic & Emergency Recovery

If you ever need an immediate, clean return to stock macOS outside the app:
```bash
make restore
# or directly:
./scripts/restore_macos.sh
```

---

## Disclaimer
Persona and Persona 3 Reload are trademarks of ATLUS / SEGA. This is an unofficial, open-source fan project aesthetic homage. No copyrighted game assets, audio files, or game textures are bundled or distributed.
