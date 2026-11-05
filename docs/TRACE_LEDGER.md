# Zero-Trace Audit Ledger (`docs/TRACE_LEDGER.md`)

Persona Mode enforces a strict **Zero-Trace Guarantee**: every system setting, temporary file, and window frame modified during an active session is recorded write-ahead before mutation and restored on exit.

---

## Session Artifact & Mutation Ledger

| Artifact / Setting | Created / Mutated When | Restored / Removed When | Mechanism |
| :--- | :--- | :--- | :--- |
| `~/Library/Application Support/PersonaMode/state.json` | Session start (before first mutation) | Verified restore (`RestoreService` / `restore_macos.sh`) | Atomic write (`0600`), deleted after verification |
| `~/Library/Application Support/PersonaMode/session.lock` | Session start (`flock`) | Deleted **last** after verified restore | Signals `guardian.sh` that clean shutdown completed |
| `~/Library/Application Support/PersonaMode/heartbeat` | Every 2s while running | Verified restore | Monitored by `guardian.sh` (`15s` hang threshold) |
| `~/Library/Application Support/PersonaMode/windows.json` | First window tile (`FrameJournal`) | Verified restore (after `restoreFrames`) | Restores pre-tiled window frames (1.0s budget) |
| `$TMPDIR/PersonaMode/profiles/` | Session start (`ProfileRenderer`) | Module stop hook & `RestoreService` temp-cleanup | Guarded by `RecoveryManager.isSafeToDelete` |
| Dock `autohide` (`com.apple.dock`) | Session start (`SystemMutator`) | Step 2 of `RestoreService` & `restore_macos.sh` | Restores exact `OriginalValue<Bool>` (`present` + `value`) |
| Menu Bar `_HIHideMenuBar` & `AppleMenuBarVisibleInFullscreen` | Session start (`SystemMutator`) | Step 2 of `RestoreService` & `restore_macos.sh` | Reconciles both scripted state and raw `NSGlobalDomain` keys |
| `Terminal.app` `"Persona 3 Reload"` Settings Set | Only if `Open Terminal (P3R)` uses `Terminal.app` fallback | Module stop hook & `restore_macos.sh` (Spike S-6) | `PlistBuddy` deletion on `com.apple.Terminal.plist` + AppleScript if running |
| User `~/.config/*` & `~/.zshrc` | **Never touched** | N/A | All CLI/terminal configs run from `$TMPDIR/PersonaMode/profiles/` |

---

## OS-Managed Entries Outside App Storage

1. **Unified Logging (`os.Logger`, subsystem `dev.persona.mode`):** Managed in-memory/ring-buffer by macOS `logd`; no custom log files are written to `~/Library/Logs`.
2. **macOS TCC Grants (`Accessibility`, `Automation`):** Stored by macOS `tccd` once approved by the user; cleared via `bash scripts/uninstall.sh` (`tccutil reset`).

