# Persona Mode

> A toggleable macOS desktop environment inspired by the Persona 3 Reload Linux Hyprland rice aesthetic.

**Zero-Trace Toggleability:**
- **Launch:** transforms macOS into the Persona 3 Reload desktop environment (custom status bar, desktop HUD widgets, active window glow border, auto-tiling with gaps, floating launcher, and isolated terminal profiles).
- **Quit (`Cmd+Q`, Menu Bar Quit, or `Ctrl+Opt+Cmd+Q` Panic):** 100% of customizations stop immediately, and macOS returns to its exact prior stock state (original wallpaper, native Dock and Menu Bar visibility restored, overlays closed, background daemons terminated) with zero permanent modifications to system files.

---

## Panic & Emergency Recovery

If you ever need an immediate, clean return to default macOS:
```bash
make restore
# or directly:
./scripts/restore_macos.sh
```

---

## Build & Test

```bash
# Check toolchain & dependencies
make doctor

# Build Swift targets
make build

# Run unit and core selftests
make test

# Package into macOS .app bundle
make app
```

---

## Disclaimer
Persona and Persona 3 Reload are trademarks of ATLUS / SEGA. This is an unofficial, open-source fan project aesthetic homage. No copyrighted game assets, audio files, or game textures are bundled or distributed.
