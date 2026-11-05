# TODO_V2 — PersonaMode V2 Visual Overhaul & Live-Mode (execution checklist)

> **Executor:** Gemini (engineering agent). **Spec:** [`OVERHAUL_ARCHITECTURE.md`](OVERHAUL_ARCHITECTURE.md) — read it fully first; section numbers (§) below refer to it. If this file and the spec disagree, stop and ask.
> **Rules of engagement**
> 1. Work **strictly in order** (V2.1 → V2.6). Do not start a phase until the previous phase gate is green and committed.
> 2. Mark a task `[x]` only after its **Verify** command(s) were actually run and passed. Never tick on "it compiles". If something can't be verified, leave it `[ ]` and write why in `docs/V2_VISUAL_LOG.md` / `docs/SPIKE_RESULTS.md`.
> 3. One git commit per phase (`V2.n: <title>`), pushed to `origin/master` after the phase gate passes.
> 4. **All V1 invariants (I1–I8) and the 1115 existing selftest assertions stay green** at every gate.
> 5. If a spike disproves an **[ASSUMPTION]**, follow the fallback in §13, record it, and adapt — do not silently work around it.

## Global guardrails (apply to every task)
- **No Swift macros:** never use `@State`, `@Observable`, `#Preview`; use `ObservableObject`/plain classes. Must build with CommandLineTools `swift build` (no full Xcode, no `xcodebuild`).
- **Never trigger an Accessibility prompt** headlessly (`AXPermission.request(prompt: false)` default). Probes/selftests/`make verify-clean` must never block on a system dialog.
- **Never bypass a permission** (Screen Recording, Accessibility, Automation). Screenshots are **off-screen renders only** — do **not** use `screencapture`, `CGWindowListCreateImage` or ScreenCaptureKit.
- **Zero-trace:** every `WKWebView` uses `WKWebsiteDataStore.nonPersistent()`; the app never creates files outside its V1 trace budget (§12.5 adds the WebKit paths); never create `config.json`, `art/` or `wallpapers/` in Application Support (I8).
- **No official Atlus assets** (art, logos incl. S.E.E.S. emblem, audio, fonts) — original vector art only; user drop-in slots only (ADR-V2-4). Do not download art.
- **Untrusted strings → `textContent`**, never `innerHTML` (§4.3).
- **Never** run tests that move the developer's windows: every automated script uses `--dry-run` or `--no-window-moves` (V2.1 makes this possible).
- **Preserve the user's uncommitted edit** to `Resources/profiles/fastfetch/config.jsonc` (`git diff` first; do not revert).
- Shell scripts: bash 3.2 compatible, `set -eu`, self-healing `trap` for anything that mutates Dock/Menu Bar.
- Commands used below: `V-BUILD` = `swift build`; `V-TEST <suite…>` = `swift run persona-selftest <suite…>` (no args = all); `V-ALL` = `swift build && swift run persona-selftest`.

## Visual QA protocol (used by every "Visual gate" task)
1. Render the PNG with the probe given in the task.
2. `swift run PersonaMode --probe png-stats <png>` → must meet the numeric bounds in §12.4.
3. **Open the PNG with the file viewer (`read_file` on the .png) and inspect it.** In `docs/V2_VISUAL_LOG.md` add a dated entry per surface listing **each rubric line from §12.4** as ☑/☐ with one sentence of evidence.
4. Any ☐ → fix → re-render → repeat. **After 5 failed iterations on one surface: stop and ask the user** (never weaken the rubric).
5. Copy the accepted PNG into `docs/screenshots/<name>.png` and reference it from the log.

---

# PHASE V2.1 — Live-mode fix, run-mode flags, safe test harness
**Goal:** `open "build/Persona Mode.app"` is LIVE by default; dry-run is explicit; automated scripts can never move the developer's windows.

- [x] **V2.1.1 `LaunchOptions` (pure, PersonaCore)**
  **Files:** `Sources/PersonaCore/App/LaunchOptions.swift`, `Sources/PersonaSelfTest/Suites/LaunchOptionsSuite.swift`, register in `Sources/PersonaSelfTest/main.swift`.
  **Details:** §7.4/§8.2. `LaunchOptions.parse(args:env:)` → `runMode (.live|.dryRun)`, `windowMoves`, `guardian`, `debugWebUI`, `deprecatedEnvWarnings`. CLI flags (`--dry-run`, `--no-window-moves`, `--no-guardian`, `--debug-webui`) beat env; `PERSONA_PHASE1_DEMO` is ignored and yields a warning string; unknown flags are ignored (the `--probe`/`--ctl`/`--restore-only` paths are handled before parsing in `main.swift`).
  **Verify:** `V-TEST launchoptions` — cases: no args/env → live+moves+guardian; `--dry-run`; `PERSONA_DRY_RUN=1`; `--dry-run` + `PERSONA_DRY_RUN=0` (CLI wins); `--no-window-moves` keeps `runMode == .live`; `PERSONA_PHASE1_DEMO=1` → warning, still live; garbage args ignored.

- [x] **V2.1.2 Wire run mode into the lifecycle**
  **Files:** `Sources/PersonaMode/main.swift`, `Sources/PersonaMode/App/LifecycleController.swift`, `Sources/PersonaKit/App/AppState.swift` (`runMode`), `Sources/PersonaKit/StatusItem/StatusBarController.swift`.
  **Details:** §8.3 items 1, 3. In `main.swift` (GUI path only) parse `LaunchOptions`, `setenv` the normalised vars (`PERSONA_DRY_RUN`, `PERSONA_NO_WINDOW_MOVES`, `PERSONA_NO_GUARDIAN`, `PERSONA_WEBUI_DEBUG`), print deprecation warnings to stderr. `LifecycleController`: load `AppConfig` **before** `SnapshotService.begin`, pass `config.wallpaper.mode` (replace the hard-coded `.overlay`), pick the adapter from run mode, keep unconditional Dock/Menu-Bar mutations in live, set `AppState.runMode`. Status menu header becomes `Persona Mode — LIVE` / `Persona Mode — DRY RUN`.
  **Verify:** `V-ALL`; `PERSONA_DRY_RUN=1 swift run PersonaMode --probe snapshot` unaffected; `bash scripts/smoke_gui.sh` → `GUI SMOKE: PASS`.

- [x] **V2.1.3 Window-move gate**
  **Files:** `Sources/PersonaKit/Accessibility/WindowRegistry.swift` (`setWindowFrame`, currently line ~277), `Sources/PersonaKit/Tiling/TilingController.swift`, `Sources/PersonaKit/Tiling/FrameJournal.swift`.
  **Details:** §8.1 #3, §8.3 #2. Gate = `PERSONA_DRY_RUN == "1" || PERSONA_NO_WINDOW_MOVES == "1"` unless `PERSONA_TILING_LIVE == "1"`. Remove every `PERSONA_PHASE1_DEMO` read. `FrameJournal.restoreFrames` obeys the same gate (nothing to restore if nothing was moved).
  **Verify:** `grep -rn "PHASE1_DEMO" Sources` → only the deprecation warning in `LaunchOptions`; `V-TEST layout` still 729 assertions green (mock provider tests unaffected); add a `LayoutSuite` case: with env `PERSONA_NO_WINDOW_MOVES=1` the **system** provider's `setWindowFrame` returns `true` without calling AX (use the existing seam / inject env reader).

- [x] **V2.1.4 Migrate scripts to the new flags**
  **Files:** `scripts/verify_clean_state.sh`, `scripts/smoke_gui.sh`, `scripts/e2e_tiling.sh`, `scripts/perf_check.sh`, new `scripts/verify_live_default.sh`.
  **Details:** `verify_clean_state.sh`: replace every `PERSONA_PHASE1_DEMO=1` with `PERSONA_NO_WINDOW_MOVES=1` (real Dock/Menu-Bar mutation, frozen windows); scenario 6's second launch must use `PERSONA_DRY_RUN=1` (it only needs to *recover* the stale state). The three other scripts already export `PERSONA_DRY_RUN=1` — keep, add a header comment explaining why. **`verify_live_default.sh` (new, ⚠ briefly changes the real Dock/menu bar, with an unconditional `trap … restore_macos.sh`):** launch the **bundle binary with no env and `--no-window-moves`**, wait for `state.json`, assert `defaults read com.apple.dock autohide` == `1` **or** `osascript … autohide of dock preferences` == `true` (proves LIVE default), `SIGTERM`, assert Dock/menu-bar fingerprint equals the pre-run fingerprint.
  **Verify:** `make verify-clean` → `PHASE 1 ZERO-TRACE: PASS`; `bash scripts/verify_live_default.sh` → `LIVE DEFAULT: PASS`; `bash scripts/restore_macos.sh` leaves a clean state; confirm none of the scripts resized any real window (watch the IDE window during the run).

- [x] **V2.1.5 Docs for run modes**
  **Files:** `README.md`, `docs/PERMISSIONS.md`.
  **Details:** §8.2 table + §8.4 first-run notes; state clearly that **live is the default** and how to run `--dry-run`; deprecate `PERSONA_PHASE1_DEMO`.
  **Verify:** README table matches the spec table exactly; `git diff --stat` shows only docs.

### ✅ Phase V2.1 gate
`V-ALL` green (≥ 1115 + new assertions) · `smoke_gui` PASS · `make verify-clean` PASS · `verify_live_default.sh` PASS · `grep PHASE1_DEMO Sources` clean · commit `V2.1: live-mode default, run-mode flags, safe harness` · push.

---

# PHASE V2.2 — Web foundation (spikes, host, scheme handler, bridge, core models)
**Goal:** a transparent, zero-trace, locked-down `WKWebView` pipeline you can render deterministically to PNG — before any pretty UI is written.

- [x] **V2.2.1 Spike S-V2-1 — transparent WKWebView on this macOS**
  **Files:** temporary `Sources/PersonaMode/Probes/ProbeWebTransparency.swift` (`--probe web-transparency`), result in `docs/SPIKE_RESULTS.md`.
  **Details:** R-V2-1. Create a borderless non-opaque window (`.clear`) at a known on-screen rect over a *known solid backdrop window* (orange, a second `NSWindow`); host a `WKWebView` (nonPersistent) loading an inline HTML page with a half-transparent cyan square and `html{background:transparent}`. Read back pixel colours by snapshotting **both** (or by `takeSnapshot` of the web view and inspecting alpha at a known corner). Test the 3 configurations: `drawsBackground=false`; `underPageBackgroundColor=.clear` only; both. Record which work. Implement the ordered fallbacks of R-V2-1 and the **runtime self-check** used by ADR-V2-9 (`WebTransparencyCheck.passes() -> Bool`).
  **Verify:** probe prints `{drawsBackgroundKVC:Bool, underPage:Bool, alphaAtCorner:Double, chosen:"…"}`; `docs/SPIKE_RESULTS.md` has an `S-V2-1` section with the chosen mechanism and the exact macOS build. Remove the probe afterwards or keep it documented in Appendix A.

- [x] **V2.2.2 Spike S-V2-2 — headless snapshot (`render webui`) + `png-stats`**
  **Files:** `Sources/PersonaMode/Probes/ProbeRenderWebUI.swift`, extend `ProbeRegistry`/`ProbeRender` dispatch (`args[0] == "webui"`), `Sources/PersonaMode/Probes/ProbePNGStats.swift`.
  **Details:** §12.1. Probe loads `persona://app/<surface>.html?fixture=<n>&freeze=<ms>&seed=<n>` in an off-screen window, waits (RunLoop pump, 8 s timeout, non-zero exit on timeout) for `document.documentElement.dataset.ready == "1"` (poll via `evaluateJavaScript`), then `takeSnapshot(with:)` honouring `--scale`, writes a PNG **with alpha**. Try the capture strategies of R-V2-2 in order until a non-blank image results; record the winner. `png-stats <png>` prints `{w,h,alphaCoveragePct,bbox,cyanPct,whitePct,navyPct}` (tolerance ±24 per channel).
  **Verify:** with a throwaway `Resources/webui/dev-smoke.html` (solid 100×100 cyan square on transparent bg) `render webui` produces a PNG whose `png-stats` shows `alphaCoveragePct ≈ square area ± 2` and `cyanPct ≈ 100 of opaque`; `docs/SPIKE_RESULTS.md` `S-V2-2` records the winning capture method. Delete `dev-smoke.html`.

- [x] **V2.2.3 `WebUIRouter` + `WebUISchemeHandler`**
  **Files:** `Sources/PersonaKit/Web/WebUIRouter.swift`, `…/WebUISchemeHandler.swift`, `Sources/PersonaSelfTest/Suites/WebRouterSuite.swift`.
  **Details:** §4.4. Pure `resolve(path:root:userDirs:)`; MIME table (`html css js svg png jpg jpeg webp heic→image/heic ttf json`); CSP header on HTML; `/wallpaper/current`, `/art/banner` (user dir precedence, read-only), `/icon/<id>.png` backed by an `IconCache` (`NSCache`). Handler implements `start`/`stop` correctly (cancel in-flight tasks).
  **Verify:** `V-TEST webrouter` — rejects `..`, `%2e%2e`, `\`, NUL, absolute paths, symlink escaping the root, sibling-prefix dirs (`webui-evil/…` must not match root `webui/`); correct MIME; user-art precedence; 404 for unknown ext; icon route never exposes a path.

- [x] **V2.2.4 `WebSurfaceView` (host, lock-down, teardown)**
  **Files:** `Sources/PersonaKit/Web/WebSurfaceView.swift`, `Sources/PersonaKit/Web/WeakScriptHandler.swift`, `Sources/PersonaSelfTest/Suites/WebSurfaceSuite.swift`.
  **Details:** §4.2 verbatim: nonPersistent store, scheme handler, navigation lock (only `persona://app`), no context menu, no magnification, no back/forward gestures, `acceptsFirstResponder=false`, `acceptsFirstMouse` per `interactive`, `isInspectable` in debug or `PERSONA_WEBUI_DEBUG=1`. Teardown func in the exact §3.2 order. Weak-proxy script handler.
  **Verify:** `V-TEST websurface` — construct (no navigation): `websiteDataStore.isPersistent == false`, `value(forKey:"drawsBackground") as? Bool == false` (or the S-V2-1 chosen mechanism), handler deinit proven with a weak reference after `teardown()`.

- [x] **V2.2.5 `WebBridge` + typed intents + ready handshake**
  **Files:** `Sources/PersonaKit/Web/WebBridge.swift`, `Resources/webui/js/bridge.js`.
  **Details:** §4.3. Swift→JS via `callAsyncJavaScript` with structured `arguments` (no string-built JS); patches queued until `ready`; JS→Swift whitelist decoding to `WebIntent`, origin check (`persona` scheme), unknown → drop. `bridge.js`: `window.persona = {state, onState(fn), dispatch(patch), post(type,payload), freeze(ms), fixture(name)}`, shallow-merge patches, `ready` after `document.fonts.load` of every face + first `requestAnimationFrame`, sets `data-ready`, implements `?freeze/&seed/&fixture`, **FrameGovernor** (single rAF, cap fps, `data-calm` support), `mulberry32`.
  **Verify:** `V-TEST websurface` extended with a pure `WebIntent.decode` table test (valid/invalid/oversized payloads, wrong scheme) and a patch-queue test; Safari `dev.html` (V2.2.7) shows state merging.

- [x] **V2.2.6 PersonaCore models: `TimeOfDaySlot`, `MoonPhase`, `WebState`**
  **Files:** `Sources/PersonaCore/Theme/{TimeOfDaySlot,MoonPhase}.swift`, `Sources/PersonaCore/Web/WebState.swift`, suites `TimeOfDaySuite`, `MoonPhaseSuite`, `WebStateSuite`.
  **Details:** §7.1–7.3 exactly (table, formulas, 8 bins, golden dates, tolerance 0.75 d). `WebState` Codable with sorted-key encoder; golden JSON fixtures stored as Swift string literals **and** mirrored in `Resources/webui/fixtures/*.json` (the suite asserts the files decode and re-encode identically).
  **Verify:** `V-TEST timeofday moonphase webstate` — every boundary minute of §7.1; `MoonPhase` new moon 2024-01-11 11:57 UTC and full moon 2024-01-25 17:54 UTC within tolerance; `toFull ∈ (0, 29.53]` over 1000 random dates; fixtures round-trip.

- [x] **V2.2.7 `Resources/webui` skeleton, tokens, fonts, dev harness**
  **Files:** `Resources/webui/{topbar,hud,launcher,dev}.html`, `css/{tokens,base,shapes}.css`, `js/{bridge,fixtures}.js`, `Sources/PersonaMode/Probes/ProbeGenTokens.swift`, `Sources/PersonaSelfTest/Suites/{TokenDriftSuite,WebAssetLintSuite}.swift`, `ThemeTokens.swift` (web-only tokens).
  **Details:** §5. `tokens.css` generated from `ThemeTokens` (`--probe gen-tokens`), all §6.1 tokens, `@font-face` for Bebas Neue / Rajdhani via `persona://app/fonts/…`. `shapes.css` = §6.2 classes + the plate recipe (pattern 5.4a) + 3-layer outline-text recipe (5.4b). Pages are empty shells that signal `ready`. `dev.html` per §5.5.
  **Verify:** `V-TEST tokendrift weblint` — drift = fail; lint fails on `innerHTML`, `http://`/`https://` literals, `eval(`, `new Function`, remote `url(`, and any CSS rule containing both `filter` and `clip-path`.

- [x] **V2.2.8 Engine switch + factory + packaging of web assets**
  **Files:** `Sources/PersonaCore/Config/AppConfig.swift` (`ui.engine`), `Sources/PersonaKit/Web/WebContentFactory.swift`, `Sources/PersonaKit/App/PersonaContentFactory.swift` (fallback), `scripts/build_app.sh`, `config/default-config.json`, `ConfigSuite`.
  **Details:** §3, ADR-V2-9, §5.1, §10.1. `WebContentFactory: WindowContentFactory` returns a `WebSurfaceView` per surface (stub pages for now); choose factory by `ui.engine`, and auto-fall back to the SwiftUI factory if `WebTransparencyCheck` fails (log + status-menu hint `UI: SwiftUI fallback`). `build_app.sh` copies `webui/` and `wallpaper/` (create the dir with a `.gitkeep` until V2.4). Clamp/validate all §10.1 keys.
  **Verify:** `V-TEST config`; `make app && ls "build/Persona Mode.app/Contents/Resources"` shows `webui`; `open -W -n "build/Persona Mode.app" --args --probe fonts --out /tmp/f.json && cat /tmp/f.json` → both faces `true` **from the bundle** (this also clears the carry-over P6.6 verification debt).

- [x] **V2.2.9 Spike S-V2-3 — baseline cost of 3 transparent webviews + trace scan**
  **Files:** `scripts/perf_check.sh` (helper accounting §11.3), `docs/SPIKE_RESULTS.md`.
  **Details:** With three **empty** `ready` surfaces running (dry-run bundle, 60 s): record app+helper CPU/RSS using the PID-diff method of §11.3; count helper processes. Then run once and check the residue paths of §12.5 after quit. Replace the *initial* budgets in §11.2 with **measured × 1.25** (edit `OVERHAUL_ARCHITECTURE.md` §11.2 and note the machine).
  **Verify:** `bash scripts/perf_check.sh 60` prints separate `app`, `webkit helpers`, `total` lines; residue paths absent (`ls ~/Library/WebKit/dev.persona.mode ~/Library/Caches/dev.persona.mode 2>&1 | grep -c "No such"` = 2) — if present, implement the scoped cleanup of §12.5 and record it.

### ✅ Phase V2.2 gate
`V-ALL` green · `render webui` produces a non-blank transparent PNG · transparency spike resolved (or SwiftUI fallback verified) · bundle `--probe fonts` true/true · baseline perf recorded and §11.2 updated · `smoke_gui` + `verify-clean` still PASS · commit `V2.2: web foundation` · push.

---

# PHASE V2.3 — Waybar-style Top Bar + native Border overhaul
**Goal:** the bar and the active-window frame read as authentic P3R at first glance.

- [x] **V2.3.1 Shape-kit contact sheet**
  **Files:** `Resources/webui/dev-shapes.html` (render target), `css/shapes.css`.
  **Details:** §6.2 — one page showing every class with the plate recipe and the 3-layer outline numerals (`11 / 05`) on `#0a192f`.
  **Verify:** `swift run PersonaMode --probe render webui shapes /tmp/v2_shapes.png --w 900 --h 520 --scale 2 --freeze 0` → open PNG; confirm: slanted parallelograms (not rectangles), chamfers, jagged frame, **drop-shadow not clipped** (the wrapper-filter pattern works), outline numerals show white/navy/cyan layers. Log in `docs/V2_VISUAL_LOG.md`.

- [x] **V2.3.2 `topbar.html` / `topbar.css` / `topbar.js`**
  **Files:** `Resources/webui/{topbar.html,css/topbar.css,js/topbar.js}`, `fixtures/bar.{default,notch,darkhour,dryrun}.json`.
  **Details:** §6.3 completely: `.s-bar` strip, emblem badge (original), workspace pills with the active slash-sweep (single allowed layout animation), focus pill with `textContent` + ellipsis, centre ticker (marquee, duplicated content, `data-calm` pause), five hardware pills with `scaleX(var(--v))` progress slashes and warn/alert colouring, clock (ticks in JS), `EXIT P3R`, `DRY RUN` chip, notch grid (`--notch-w`). Hover/active states per spec. Intents: `post("switchSpace",{n})`, `post("exit")`. JS never uses `innerHTML`.
  **Verify:** Safari `dev.html` renders all four fixtures; `V-TEST weblint` clean.

- [x] **V2.3.3 Swift wiring: bar content, publisher, geometry, tiler inset**
  **Files:** `Sources/PersonaKit/Web/WebStatePublisher.swift`, `Sources/PersonaKit/Web/WebContentFactory.swift` (`makeBarContent`), `Sources/PersonaKit/Windows/TopBarPanel.swift`, `Sources/PersonaCore/Config/AppConfig.swift` + `config/default-config.json` (`topBar.height` 44), `Sources/PersonaCore/Layout/WindowGeometry.swift` (if constants), selftest goldens.
  **Details:** publisher subscribes to `AppState` (`focusedApp/Title`, `spaceSnapshot`, `telemetry`, `nowPlaying`, `darkHourPhase`, `axTrusted`, `tilingEnabled`, `runMode`, `soundMuted`) and publishes **diff patches**, telemetry ≤ 2 Hz, coalesced per run-loop turn. Bar window 44 pt tall; send `screen.notch` from `ScreenModel.auxLeft/auxRight`. Intents: `switchSpace` → `SpaceProvider.switchTo(spaceIndex:)`, `exit` → `CommandRouter.send(.exitPersona)`. Tiler reserves the new height automatically (`max(38, config.height, safeTop)`); update goldens that hard-code the old default **deliberately** and add an assertion that tiled windows never overlap the 44 pt bar on 1512×982 and 2560×1440 (non-zero origin).
  **Verify:** `V-ALL` green; `bash scripts/smoke_gui.sh` PASS (still 2 + border windows, correct layers `[-2147483604, 25]`); `PERSONA_DRY_RUN=1 swift run PersonaMode --probe windows --seconds 2` reports bar height `max(44, safeTop)` (record the real value and display type in the log); first-click works on the first press without activating the app (manual note in log).

- [x] **V2.3.4 `BorderOverlayWindow` P3R frame (native)**
  **Files:** `Sources/PersonaKit/Windows/BorderOverlayWindow.swift`, `Sources/PersonaCore/Config/AppConfig.swift` (`border.style`, `border.bracketLength`), `Sources/PersonaKit/Border/BorderController.swift` (pass style), `ProbeRender` border target, `LayoutSuite`/new `BorderSuite`.
  **Details:** §6.8: five layers (`glowOuter`, `glowInner`, `frame`, `brackets`, `ticks`), chamfered bracket polygon `(0,0)→(L,0)→(L−4,T)→(T,T)→(T,L−4)→(0,L)` mirrored by affine transforms, group rasterisation re-done only on rect change, glow-opacity pulse 2.4 s, `plain` style = V1 look. Keep the Guardrail-4 locks verbatim. Replace the SwiftUI `BorderPreviewView` render path with a render of the **real window layers** over a synthetic dark window (layer `render(in:)`).
  **Verify:** `V-TEST layout` (all prior border assertions unchanged and green) + new assertions: 5 sublayers exist; `ignoresMouseEvents == true` after attempted set; `bracketLength` clamps 16…48; ring rect equality early-out (no layer churn). `swift run PersonaMode --probe render border /tmp/v2_border.png --w 800 --h 520 --scale 2`.

- [x] **V2.3.5 Visual gate — top bar + border**
  **Files:** `docs/V2_VISUAL_LOG.md`, `docs/screenshots/`.
  **Details:** follow the **Visual QA protocol** with the §12.4 **Top bar** and **Border** rubrics.
  **Verify:** all of:
  ```bash
  swift run PersonaMode --probe render webui topbar /tmp/v2_topbar.png --fixture bar.default --w 1512 --h 44 --scale 2 --freeze 1200 --seed 7
  swift run PersonaMode --probe render webui topbar /tmp/v2_topbar_notch.png --fixture bar.notch --w 1512 --h 44 --scale 2 --freeze 1200 --seed 7
  swift run PersonaMode --probe render webui topbar /tmp/v2_topbar_dark.png --fixture bar.darkhour --w 1512 --h 44 --scale 2 --freeze 1200 --seed 7
  swift run PersonaMode --probe render border /tmp/v2_border.png --w 800 --h 520 --scale 2
  for f in /tmp/v2_topbar.png /tmp/v2_topbar_notch.png /tmp/v2_topbar_dark.png /tmp/v2_border.png; do swift run PersonaMode --probe png-stats "$f"; done
  ```
  then **view each PNG** and tick the rubric lines in the log. Gate is the log, not the exit code.

- [x] **V2.3.6 Perf checkpoint**
  **Verify:** `bash scripts/perf_check.sh 30` (dry-run) stays within the §11.2 numbers recorded in V2.2.9; record in the log.

### ✅ Phase V2.3 gate
`V-ALL` green · rubric for `/tmp/v2_topbar*.png` and `/tmp/v2_border.png` fully ticked with evidence and screenshots committed · `smoke_gui` PASS · `e2e_tiling` PASS · perf within budget · commit `V2.3: P3R top bar and border` · push.

---

# PHASE V2.4 — Desktop HUD, layered wallpaper, ambient animation
**Goal:** the desktop itself looks like the reference, and it *moves* — within the measured budget.

- [ ] **V2.4.1 Wallpaper layers + generator**
  **Files:** `Resources/webui/{hud.html,css/hud.css,svg/*}`, `Resources/webui/wallpaper.html` (layers L0–L5, L7–L8 only, no canvas), `scripts/gen_wallpaper.sh`, `Resources/wallpaper/p3r_wallpaper.png`.
  **Details:** §6.6 table exactly: gradient, 6 ocean bands, giant moon + **original** spire silhouette, 4 slashes (`polygon(0 62%,100% 38%,100% 46%,0 70%)`, …), halftone pattern with radial mask, outline typography (`MEMENTO MORI`, `DARK HOUR`), rings, vignette. Static layers `contain: paint`. `gen_wallpaper.sh` renders the PNG from the same HTML (`--probe render webui wallpaper … --w 3840 --h 2160 --scale 1 --freeze 0`).
  **Verify:** `bash scripts/gen_wallpaper.sh && file Resources/wallpaper/p3r_wallpaper.png && ls -l Resources/wallpaper/p3r_wallpaper.png` → 3840×2160, size reported (if > 6 MB, reduce noise per §6.6; do **not** JPEG); `/tmp/v2_wallpaper.png` viewed per protocol.

- [ ] **V2.4.2 Date / time-of-day / moon HUD**
  **Files:** `Resources/webui/{css/hud.css,js/{hud,moon}.js,svg/moon-ring.svg}`, `fixtures/hud.{afterschool,darkhour}.json`.
  **Details:** §6.4 A–D: three-layer numerals (`11`, `/`, `05`), `THU` badge, banner with slot animation + accent per slot, moon ring (12-segment dashed ring `r=88 stroke-dasharray 38.07 8`, 6 chambers, ticks, counter-rotating inner ring, phase disc via the §7.2 path algorithm), `NEXT FULL MOON T-xxD xxH` chip + <24 h pulse, Dark Hour recolour (`[data-phase="darkHour"]`). Slot/moon come from Swift (`TimeOfDaySlot`, `MoonPhase`), DOW from `Locale(en_US_POSIX)` uppercase.
  **Verify:** Safari `dev.html` at `p = 0, .25, .5, .75` shows new/first-quarter/full/last-quarter discs.

- [ ] **V2.4.3 Now-Playing HUD + equalizer**
  **Files:** `Resources/webui/{css/hud.css,js/eq.js,svg/{vinyl,wings,halftone}.svg}`.
  **Details:** §6.5: `.s-jag` frame with white/ink/face plates, vinyl + wings (original), title marquee only on overflow, artist chip, 28-bar canvas EQ (seeded procedural model, attack .5 / release .12, `data-source="synthetic"`), halftone sweep as a **transform on a static masked layer**, states playing/paused/none.
  **Verify:** unit-style check in `dev.html` toggling the three states; `V-TEST weblint` clean.

- [ ] **V2.4.4 Ambient layers + `PowerStateMonitor` (calm mode)**
  **Files:** `Resources/webui/js/bubbles.js`, `Sources/PersonaKit/App/PowerStateMonitor.swift`, `Sources/PersonaKit/App/AppState.swift` (`ambientPaused` now has a writer), `WebStatePublisher` (`calm`).
  **Details:** §6.6 L6/L7 and §11.1 table: bubbles via `FrameGovernor` (24 fps default, ≤ `hud.particles`), CSS-only rings; `PowerStateMonitor` observes Low Power Mode, battery < 20 % unplugged (existing sampler), display sleep/wake, full-screen frontmost, `thermalState ≥ .serious`; publishes `calm` → `html[data-calm=1]` (rAF stops, CSS animations paused) **and** `AppState.ambientPaused` (legacy engine benefits). Add a pure `CalmPolicy.decide(inputs) -> Bool` in PersonaCore.
  **Verify:** `V-TEST calm` (truth table for every input combination, hysteresis on battery 20↔25 %); manual: toggle Low Power Mode → HUD motion stops within 2 s (note in log).

- [ ] **V2.4.5 Desktop overlay hosts the web HUD; wallpaper modes**
  **Files:** `Sources/PersonaKit/Windows/DesktopOverlayWindow.swift`, `Sources/PersonaKit/Web/WebContentFactory.swift` (`makeOverlayContent`), `Sources/PersonaKit/Windows/WindowHostManager.swift`, `Sources/PersonaMode/App/LifecycleController.swift` (system wallpaper path), `Sources/PersonaCore/Lifecycle/*` only if a new ledger case is unavoidable (it should not be — reuse `.tempDir` + `.systemWallpaper`).
  **Details:** §6.6, ADR-V2-6, §8.3 #4. Overlay stays `ignoresMouseEvents == true` (hard lock untouched), level `desktopIcon−1`. `wallpaper.mode == system`: export PNG to `$TMPDIR/PersonaMode/wallpaper/`, apply via the existing mutator, refuse + fall back to overlay when any snapshot is non-restorable; `none` hides the wallpaper layers but keeps widgets. `/wallpaper/current` honours the user drop-in dir (read-only).
  **Verify:** `V-ALL`; `V-TEST mutator restore` unchanged green; `bash scripts/smoke_gui.sh` PASS; with a temp support dir and `PERSONA_DRY_RUN=1` the system-wallpaper path logs the DRYRUN calls and leaves no files after quit.

- [ ] **V2.4.6 Visual gate — HUD, wallpaper, composite**
  **Details:** protocol with the §12.4 **HUD** rubric.
  **Verify:**
  ```bash
  swift run PersonaMode --probe render webui hud /tmp/v2_hud.png --fixture hud.afterschool --w 1512 --h 982 --scale 1 --freeze 1500 --seed 7
  swift run PersonaMode --probe render webui hud /tmp/v2_hud_darkhour.png --fixture hud.darkhour --w 1512 --h 982 --scale 1 --freeze 1500 --seed 7
  swift run PersonaMode --probe render webui wallpaper /tmp/v2_wallpaper.png --w 1512 --h 982 --scale 1 --freeze 0
  swift run PersonaMode --probe render composite /tmp/v2_composite.png --w 1512 --h 982
  for f in /tmp/v2_hud.png /tmp/v2_hud_darkhour.png /tmp/v2_wallpaper.png /tmp/v2_composite.png; do swift run PersonaMode --probe png-stats "$f"; done
  ```
  View all four; the composite (wallpaper + HUD + top bar) is the "does it look like the reference" check — log it.

- [ ] **V2.4.7 Perf gate with animation on**
  **Verify:** `bash scripts/perf_check.sh 60` (dry-run, AC): total CPU ≤ budget (animated), then with `PERSONA_HUD_ANIMATION=0`/calm ≤ calm budget; RSS ≤ budget. If over: lower `hud.fps`/`particles`, remove a layer, or share work — **record before/after in the log; do not weaken budgets without measured justification.**

### ✅ Phase V2.4 gate
`V-ALL` green · all four PNGs rubric-ticked with committed screenshots · wallpaper PNG generated and committed · animated + calm perf within budget · `smoke_gui`/`e2e_tiling`/`verify-clean` PASS · commit `V2.4: HUD, wallpaper, ambient` · push.

---

# PHASE V2.5 — Rofi-style split-panel Launcher + UI sound effects
**Goal:** `⌥Space` produces the signature P3R command menu with the white/cyan selection slash.

- [ ] **V2.5.1 `launcher.html` split layout + original banner art**
  **Files:** `Resources/webui/{launcher.html,css/launcher.css,js/launcher.js,svg/{banner_default,seal_original}.svg}`, `fixtures/launcher.{default,query-saf,exit-selected}.json`.
  **Details:** §6.7: 372/608 split with 52 px diagonal, gradient + halftone burst + 3 slash bars + art slot + vertical `S.E.E.S. COMMAND` (3-layer outline text) + diagonal divider strips; search bar with `SEARCH ▸` badge and blinking block caret; 8 visible rows (50 px, gap 4), icons via `/icon/<id>.png`, tag chips, `⌘1…9` hints; **selected row**: solid `#ffffff` face, `#050c1a` text, cyan plate `(6,6)` + ink mid plate `(3,3)`, red↔cyan triangle cursor, 140 ms `--ease-snap` slide (face `translateX(-100%→0)` inside an `overflow:hidden` clipped row, body `translateX(14px)`); `EXIT` row crimson variant; `<mark>` highlights built with `textContent` spans; enter animation 160 ms; **no exit animation**. `banner_default.svg` is **original** geometry (crescent, hourglass, hex rings, blade) — no tracing.
  **Verify:** Safari `dev.html` shows the three fixtures; `V-TEST weblint` clean.

- [ ] **V2.5.2 Native adapter: `LauncherViewModel` → web, mouse intents, panel**
  **Files:** `Sources/PersonaKit/Launcher/LauncherWebAdapter.swift`, `Sources/PersonaKit/UI/Launcher/LauncherPanel.swift`, `Sources/PersonaKit/Launcher/LauncherController.swift`, `Sources/PersonaCore/Config/AppConfig.swift` (`launcher.width/height`).
  **Details:** §6.7, ADR-V2-8. Adapter observes `LauncherViewModel` (`query`, `matches`, `selectedIndex`, scroll window) and publishes `LauncherState` patches (match ranges, kind, shortcut, destructive flag, icon ids). **Keep the `NSEvent` monitor and `handleKeyCode` untouched.** Mouse hover/click → `launcherHover(i)` / `launcherActivate(i, reveal:)` → `LauncherViewModel`. Panel: size from config (`min(width, 0.8·screen)`), 38 % vertical centring unchanged, `hasShadow=false`, **remove `NSVisualEffectView`**, pre-warm the page hidden at start (launcher-open budget §11.2), `hide()` stays synchronous.
  **Verify:** `V-TEST fuzzy` (every existing launcher/hotkey assertion stays green, including `launcher level == 100`, `Esc dismisses`, `focus loss dismisses`); `swift run PersonaMode --probe launcher-open --out /tmp/lo.json` → `{level:100, canBecomeKey:true, visibleAfterShow:true, visibleAfterEsc:false}`; `--probe apps --query saf` still ranks Safari first.

- [ ] **V2.5.3 `SoundFX` + mute + hooks**
  **Files:** `Sources/PersonaKit/Audio/SoundFX.swift`, `Sources/PersonaCore/Config/AppConfig.swift` (`sound.*`, `hotkeys.mute`), `AppState.swift` (`soundMuted`), `CommandRouter.swift` (`toggleMute`), `StatusBarController.swift` (`Mute UI Sounds` ✓ item), `LauncherController.swift` (hooks), `HotKeyCenter.swift` (`hotkeys.mute`), `Sources/PersonaSelfTest/Suites/SoundSuite.swift`.
  **Details:** §6.9 recipes (tick, confirm, cancel, open), `AVAudioEngine` started lazily on first cue, all failures swallowed (no output device ⇒ silent), silent when `PERSONA_DRY_RUN=1`, `enabled` default true, in-memory mute only (I8). Hooks: `moveSelectionUp/Down` → tick, activate → confirm, `Esc` → cancel, `show()` → open.
  **Verify:** `V-TEST sound` — offline buffers: length ≈ spec ±2 ms, peak ∈ (0.05, 0.9), RMS > 0, no NaN, deterministic (identical on two renders); `--ctl mute` toggles state (`CommandRouter` unit test).

- [ ] **V2.5.4 Probes + selftests updated**
  **Files:** `ProbeRender` launcher target → web, `ProbeLauncher`, `FuzzySuite` (only if a seam changed).
  **Details:** `--probe render webui launcher /tmp/v2_launcher.png --fixture launcher.default …` is the new canonical render; keep `--probe render launcher` as an alias to it (document in Appendix A).
  **Verify:** `V-ALL` green.

- [ ] **V2.5.5 Visual gate — launcher**
  **Details:** protocol with the §12.4 **Launcher** rubric. The **selected-row look is the acceptance centrepiece** (white face / navy text / ≥ 5 px cyan plate / triangle cursor).
  **Verify:**
  ```bash
  swift run PersonaMode --probe render webui launcher /tmp/v2_launcher.png            --fixture launcher.default       --w 980 --h 560 --scale 2 --freeze 800 --seed 7
  swift run PersonaMode --probe render webui launcher /tmp/v2_launcher_saf.png        --fixture launcher.query-saf     --w 980 --h 560 --scale 2 --freeze 800 --seed 7
  swift run PersonaMode --probe render webui launcher /tmp/v2_launcher_exit.png       --fixture launcher.exit-selected --w 980 --h 560 --scale 2 --freeze 800 --seed 7
  for f in /tmp/v2_launcher.png /tmp/v2_launcher_saf.png /tmp/v2_launcher_exit.png; do swift run PersonaMode --probe png-stats "$f"; done
  ```
  View all three; also render the user-drop-in path once with a temporary PNG in a **temp** `PERSONA_SUPPORT_DIR/art/` to prove the override works (delete afterwards; never commit it).

### ✅ Phase V2.5 gate
`V-ALL` green · launcher rubric ticked ×3 with screenshots · `launcher-open` probe OK · SFX suite green · `smoke_gui`/`verify-clean` PASS · perf within budget (`perf_check.sh 30`) · commit `V2.5: split-panel launcher + SFX` · push.

---

# PHASE V2.6 — Showcase workspace, packaging, zero-trace audit, final gates
**Goal:** one click reproduces the screenshot; the whole thing is shippable and honestly verified.

- [ ] **V2.6.1 `ShowcaseController` + command plumbing**
  **Files:** `Sources/PersonaKit/Showcase/ShowcaseController.swift`, `Sources/PersonaKit/App/CommandRouter.swift` (`spawnShowcase`, `--ctl showcase`), `Sources/PersonaKit/Launcher/AppIndexer.swift`/`LauncherItem.swift` (action `showcase`, "Launch P3R Showcase Workspace"), `StatusBarController.swift`, `HotKeyCenter.swift` (`hotkeys.showcase`), `LifecycleController.swift` (wire), `ShowcaseSuite`.
  **Details:** §9. Pure planner `ShowcasePlan.make(detection:, screen:, bar:, gaps:, hasCava:, hasBtop:) -> {commands:[String], frames:[CGRect], fallbacks:[String]}` in PersonaCore (frames from `LayoutEngine` for 2 ids — must respect the 44 pt bar inset); controller executes it.
  **Verify:** `V-TEST showcase` — plan has exactly 2 commands; window B chain picks `cava` > `btop` > `p3r_monitor.sh`; frames inside usable area, `minY ≥ marginTop + 44 + outer`; no overlap; seam == inner gap; `CommandRouter` maps `showcase`.

- [ ] **V2.6.2 Multi-window terminal launch + monitor script**
  **Files:** `Sources/PersonaKit/Terminal/TerminalLauncher.swift` (`launchMany`), `Resources/profiles/bin/p3r_monitor.sh`, `ProfileRenderer.swift` (copy `bin/` preserving `0755`), `Resources/profiles/cava/config` (keep user's palette), `docs/PERMISSIONS.md`.
  **Details:** §9. Terminal.app path: `do script "<cmd>"` ×2 (each creates a window), apply settings set `"Persona 3 Reload"`, ledgered profile import as before (write-ahead `.terminalProfile`); other terminals reuse the existing builders with their config flags. After spawn: if AX trusted → poll `WindowRegistry` (5 s) then `TilingController.retileAll()`; else apply planned frames via AppleScript `set bounds of window id N` (top-left coords). `p3r_monitor.sh`: bash 3.2, 1 s loop, `top -l 1 -n 0`, `vm_stat`, `ps -Ao %cpu,comm -r | head`, cyan/white ANSI bars, hides cursor, restores it on `trap EXIT`. Showcase windows stay open on exit (documented in `docs/TRACE_LEDGER.md`).
  **Verify:** `PERSONA_DRY_RUN=1 swift run PersonaMode --probe showcase --dry --out /tmp/sc.json && plutil -extract commands raw -o - /tmp/sc.json` prints the 2 commands; `bash -n Resources/profiles/bin/p3r_monitor.sh` and a 3-iteration run (`timeout 4 bash …`) prints bars; `shellcheck`-style review by eye. **Manual (⚠ opens 2 Terminal windows, ledgered):** from the bundle, choose the launcher action → two tiled windows (fastfetch with P3R colours | monitor); quit → `defaults read com.apple.Terminal "Window Settings" | grep -c "Persona 3 Reload"` → `0`.

- [ ] **V2.6.3 Complete the real zero-trace audit (clears carry-over P6.7)**
  **Files:** `scripts/verify_clean_state.sh` (`--all`), `Sources/PersonaMode/main.swift` (hidden `--crash-test`), `docs/TRACE_LEDGER.md`.
  **Details:** drive the **bundled** app with the exact 12 scenarios of `TODO.md` P6.7 (AppleScript quit, `--ctl quit`, `--ctl panic`, SIGINT, SIGTERM, SIGHUP, SIGKILL+guardian, SIGSTOP hang `PERSONA_HANG_SECONDS=4`, `--crash-test` `fatalError` after activation, stale-state relaunch, AX-denied launch+quit, Terminal.app profile launched then quit) using `--no-window-moves`. Extend the fingerprint with the WebKit paths of §12.5 and the residue scan (`find ~/Library ~/.config -newer "$MARKER" …` must list nothing under `PersonaMode`/`dev.persona.mode` and nothing in `~/.config`). Print the allowed-residue list (TCC only + the documented showcase windows).
  **Verify:** `make verify-clean` → `SCENARIO 1…12: PASS` and `ZERO-TRACE AUDIT: PASS`; if a path leaks, fix the cause (not the test).

- [ ] **V2.6.4 Soak + long perf (clears carry-over P6.8)**
  **Verify:** `bash scripts/perf_check.sh 120` on the **real bundle** (dry-run) within §11.2; manual soak recorded in `docs/V2_VISUAL_LOG.md`: change display resolution (System Settings → Displays) → bar/HUD/border re-layout; sleep/wake; Space switch; a full-screen app → HUD enters calm, tiler skips it; Low Power Mode toggle. Note anything not testable on this machine honestly.

- [ ] **V2.6.5 Packaging + docs**
  **Files:** `scripts/build_app.sh`, `Makefile` (`make showcase` convenience optional), `README.md`, `ARCHITECTURE.md` (§5 window table, §8.1/8.2/8.5, §14 budgets, §15 legal addendum for drop-in art), `docs/{TRACE_LEDGER,SPIKE_RESULTS,PERMISSIONS}.md`, `.gitignore` (`Resources/webui/dev-art/`).
  **Details:** README rewritten with: what it looks like (embed `docs/screenshots/*`), install/run (LIVE default, `--dry-run`), first-run permissions, hotkeys (+showcase, +mute), drop-in art/wallpaper instructions + the "never commit game assets" note, uninstall, **panic = `⌃⌥⌘Q` or `scripts/restore_macos.sh`**, known limitations (synthetic EQ, TCC resets on rebuild, showcase windows stay open, cava needs a loopback device). `ARCHITECTURE.md` reconciled with the spikes (S-V2-1/2/3 outcomes).
  **Verify:** `git clone . /tmp/pm && cd /tmp/pm && make app` works from a clean clone (copy-paste the README commands); `plutil -lint` + `codesign --verify --deep --strict "build/Persona Mode.app"`; `ls "build/Persona Mode.app/Contents/Resources"` has `webui wallpaper fonts profiles scripts`.

- [ ] **V2.6.6 Final composite visual gate + human sign-off**
  **Details:** re-render **everything** from the final build and re-run the full rubric:
  ```bash
  swift run PersonaMode --probe render composite /tmp/v2_composite.png --w 1512 --h 982
  ```
  plus `/tmp/v2_topbar.png`, `/tmp/v2_hud.png`, `/tmp/v2_launcher.png`, `/tmp/v2_border.png`. Create `docs/V2_SIGNOFF.md` with the checklist below for the **user** (the agent cannot grade "authentic"; it can only prove the rubric items):
  - ☐ Top bar: S.E.E.S.-style badge, slanted pills, active-workspace slash, `EXIT P3R`
  - ☐ Date `11 / 05 THU` with `AFTER SCHOOL` banner and moon ring
  - ☐ Now-playing jagged frame + vinyl + equalizer
  - ☐ Animated bubbles/rings visible and smooth; calm mode stops them
  - ☐ `⌥Space` launcher: banner left, white/cyan selection slash right, triangle cursor, SFX
  - ☐ Active window shows corner brackets + double glow
  - ☐ Showcase action opens two tiled terminals
  - ☐ `EXIT P3R` / `⌃⌥⌘Q` returns macOS exactly as before (Dock, menu bar, windows)
  Ask the user to run the app and tick it; record their answers verbatim. **Do not mark V2 complete before the user replies.**

- [ ] **V2.6.7 Release gate (in this order)**
  **Verify:**
  ```bash
  swift build
  swift run persona-selftest                 # all suites, 0 failed
  bash scripts/perf_check.sh 60              # PERF OK against §11.2 (app + WebKit helpers)
  bash scripts/smoke_gui.sh                  # GUI SMOKE: PASS
  bash scripts/e2e_tiling.sh                 # TILING E2E: PASS
  bash scripts/verify_live_default.sh        # LIVE DEFAULT: PASS
  make verify-clean                          # SCENARIO 1…12: PASS, ZERO-TRACE AUDIT: PASS
  bash scripts/restore_macos.sh              # clean
  make app && cp -R "build/Persona Mode.app" ~/Desktop/   # refresh the Desktop clone (replace, don't nest)
  ```
  then `git add -A && git commit -m "V2.6: showcase, audit, packaging" && git push origin master`.

### ✅ Phase V2.6 / V2 release gate
All gates above green · 12-scenario audit real · WebKit residue absent · rubric logs + screenshots committed · user sign-off recorded · README accurate · no `TODO`/`FIXME` without a "Known limitations" entry.

---

## Appendix A — New probes & scripts
| Command | Purpose |
|---------|---------|
| `--probe render webui <topbar\|hud\|launcher\|wallpaper\|shapes> <out.png> [--fixture n --w --h --scale --freeze ms --seed n --phase darkHour]` | Deterministic off-screen web render |
| `--probe render composite <out.png>` | Layered mock "screenshot" |
| `--probe render border <out.png>` | Real `BorderOverlayWindow` layers over a dummy window |
| `--probe render launcher …` | alias of `render webui launcher` |
| `--probe png-stats <png>` | Numeric image sanity |
| `--probe gen-tokens` | Regenerate `tokens.css` |
| `--probe web-transparency` | S-V2-1 |
| `--probe showcase --dry` | Showcase plan, no side effects |
| `--ctl showcase \| mute` | Remote actions |
| `scripts/gen_wallpaper.sh` | Re-export `p3r_wallpaper.png` |
| `scripts/verify_live_default.sh` | Proves LIVE-by-default end to end |

## Appendix B — Dependency order (do not parallelise)
`V2.1 (flags/harness) → V2.2 (spikes + web host + core models) → V2.3 (bar + border) → V2.4 (HUD/wallpaper/ambient) → V2.5 (launcher + SFX) → V2.6 (showcase + audit + packaging + sign-off)`. Rationale: V2.1 removes the risk that any later automated run touches real windows; V2.2 resolves the two highest-risk assumptions (transparency, headless snapshot) before ~2000 lines of CSS depend on them.
