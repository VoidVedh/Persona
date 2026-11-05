# Permissions Guide (`dev.persona.mode`)

Persona Mode uses the minimum macOS permissions required to provide window tiling and live Dock/Menu Bar toggling, and **degrades gracefully** when any permission is not granted.

---

## 1. Accessibility (`AXIsProcessTrusted`)

- **Used for:**
  - Reading active window frames and titles (`AXUIElement`) for the cyan active-window glow border and Top Bar focus title.
  - Moving and resizing normal-layer application windows during automatic **Dwindle / Master-Stack** tiling.
- **When denied:**
  - Headless probes, `persona-selftest`, and `make verify-clean` **never** trigger an interactive macOS permission dialog (`AXPermission.request(prompt: false)`).
  - The Active-Window Border falls back to `CGWindowListCopyWindowInfo` bounds.
  - The Tiling Engine logs a clean warning and no-ops without crashing.
- **How to grant:**
  1. Build the app bundle: `make app`
  2. Open **System Settings → Privacy & Security → Accessibility**
  3. Enable `Persona Mode.app` (`build/Persona Mode.app`)
- **How to reset:**
  ```bash
  tccutil reset Accessibility dev.persona.mode
  ```

---

## 2. Automation (`System Events`, `Music`, `Spotify`, `Terminal`)

- **Used for:**
  - `System Events`: Toggling Dock and Menu Bar autohide live without `killall Dock`.
  - `Music` / `Spotify`: Seeding initial Now-Playing track metadata at launch **only if the player is already running**.
  - `Terminal`: Removing the temporary `"Persona 3 Reload"` profile if `Terminal.app` fallback was used.
- **How to reset:**
  ```bash
  tccutil reset AppleEvents dev.persona.mode
  ```

---

## 3. Permissions Never Requested

- **Screen Recording:** Never required (window bounds/layers use `CGWindowListCopyWindowInfo` without window name capture; titles come from Accessibility).
- **Input Monitoring:** Never required (global hotkeys use Carbon `RegisterEventHotKey`).
- **Location Services:** Never required (Wi-Fi telemetry reads RSSI signal bars, never SSID).
- **Full Disk Access:** Never required.

