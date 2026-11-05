# Persona Mode V2 — Visual QA & Rubric Log

This document records the visual inspection gate (`OVERHAUL_ARCHITECTURE.md §12.3–12.4`) and quantitative `png-stats` verification for every V2 surface.

---

## Phase V2.3 — Shape Kit, Waybar-Style Top Bar & 5-Layer Active-Window Border

### 1. Shape-Kit Contact Sheet (`V2.3.1` — `docs/screenshots/v2_shapes.png`, 1800×1040 px)

- **Command:** `swift run PersonaMode --probe render webui shapes /tmp/v2_shapes.png --w 900 --h 520 --scale 2 --freeze 0`
- **`png-stats`:**
  ```json
  {
    "alphaCoveragePct": 92.79,
    "bbox": [24, 24, 1775, 1015],
    "cornerAlphaPct": [0, 0, 0, 0],
    "cyanPct": 2.67,
    "navyPct": 85.01,
    "whitePct": 8.93,
    "w": 1800,
    "h": 1040
  }
  ```
- **Visual Verification:**
  - [x] Slanted parallelograms (`.s-para`, `.s-para-r`) render with crisp diagonal edges and zero rectangular fallback.
  - [x] Chamfered plates (`.s-chamfer`, `.s-tab-right`, `.s-bar`) show 3-layer offset backing plates (`#00d8ff` cyan back, `#050c1a` ink mid, `#ffffff`/`#050c1a` face).
  - [x] Jagged comic frame (`.s-jag`) renders multi-tooth polygon edges with `#ffffff` and `#050c1a` offset backing plates.
  - [x] Wrapper `filter: drop-shadow(...)` is never clipped by inner `clip-path: polygon(...)` (pattern 5.4a confirmed).
  - [x] 3-layer outline numerals (`11 / 05`) show crisp white front fill, thick `#050c1a` mid outline at `(5px, 5px)`, and `#00d8ff` cyan back plate at `(10px, 10px)`.

---

### 2. Waybar-Style Top Bar (`V2.3.5` — `docs/screenshots/v2_topbar*.png`, 3024×88 px @2x)

- **Commands:**
  ```bash
  swift run PersonaMode --probe render webui topbar /tmp/v2_topbar.png --fixture bar.default --w 1512 --h 44 --scale 2 --freeze 1200 --seed 7
  swift run PersonaMode --probe render webui topbar /tmp/v2_topbar_notch.png --fixture bar.notch --w 1512 --h 44 --scale 2 --freeze 1200 --seed 7
  swift run PersonaMode --probe render webui topbar /tmp/v2_topbar_dark.png --fixture bar.darkhour --w 1512 --h 44 --scale 2 --freeze 1200 --seed 7
  ```
- **`png-stats`:**
  - `v2_topbar.png` (`bar.default`): `alphaCoveragePct = 79.92%` (target `25–90%`), `cornerAlphaPct = [0, 0, 0, 0]` (`< 5%`), `cyanPct = 11.12%` (`≥ 2%`), `whitePct = 7.77%` (`≥ 1.5%`).
  - `v2_topbar_notch.png` (`bar.notch`): `alphaCoveragePct = 68.19%`, `cornerAlphaPct = [0, 0, 0, 0]`, `cyanPct = 9.66%`, `whitePct = 9.11%`.
  - `v2_topbar_dark.png` (`bar.darkhour`): `alphaCoveragePct = 79.92%`, `cornerAlphaPct = [0, 0, 0, 0]`, `cyanPct = 8.16%`, `whitePct = 7.82%`.
- **Rubric Verification (`§12.4 Top bar`):**
  - [x] **Transparent corners (alpha < 5% at the 4 corner pixels outside the strip):** `cornerAlphaPct` is `[0, 0, 0, 0]` on all three variants (`bbox: [32, 6, 2991, 77]`).
  - [x] **Strip has chamfered bottom corners:** `.s-bar` clips 28px diagonal chamfers at the bottom-left and bottom-right with a cyan/azure offset plate beneath.
  - [x] **Emblem badge white face with cyan offset plate:** Leftmost `S.E.E.S.` badge renders with a `#ffffff` chamfered face, crescent glyph, `#050c1a` mid plate, and `#00d8ff` `(3,3)` offset plate.
  - [x] **Active workspace pill visibly wider, white with cyan plate and slash highlight:** Active pill (`01` in default, `02` in Dark Hour) expands to `66px` width with a solid `#ffffff` face, `#050c1a` numeral, `#00d8ff` `(3,3)` plate, and an internal skewed cyan slash bar on the left.
  - [x] **Inactive pills are slanted parallelograms (not rectangles):** Pills `02`–`05` render as `32×25` `.s-para` slanted parallelograms with top-right occupied dots on `02`/`03` and dimmed opacity on unoccupied `04`/`05`.
  - [x] **Five hardware pills each with a mini progress slash, values legible:** `CPU 18%`, `MEM 46%`, `BAT ⚡84%`, `WIFI 4/4`, and `VOL 65%` each render inside `72×25` `.s-para` plates with zero text clipping and a slanted 4px progress bar at the bottom scaled by `scaleX(var(--v))`.
  - [x] **Clock large with cyan back copy:** `16:30` (and `00:00` in Dark Hour) renders in 25px Bebas Neue with a `#00d8ff` `(2,2)` shadow copy and stacked `THU` / `05` to the right.
  - [x] **`EXIT P3R` crimson with cyan plate:** Rightmost button has a `#ff3b5c` crimson chamfered face, white `EXIT P3R` text, `#050c1a` mid plate, and `#00d8ff` `(3,3)` offset plate.
  - [x] **Nothing clipped; notch variant leaves a clear centre gap ≥ `notch-w`:** After widening `.hw-pill` from `64px` to `72px` in iteration 2, `BAT ⚡84%` has full right-side clearance; `v2_topbar_notch.png` leaves a completely transparent 212pt (`424px` @2x) center gap between the left and right chamfered wings.
  - [x] **Live window geometry check (`--probe windows`):** On the built-in display (`1710×1112`, `safeTop = 38`), `TopBarPanel` reports `Height = 44` (`max(44, 38) = 44`) at WindowServer `layer = 25`, `canBecomeKey = false` (first click delivers directly to the webview without activating `PersonaMode`).

---

### 3. Active-Window Border (`V2.3.5` — `docs/screenshots/v2_border.png`, 1600×1040 px @2x)

- **Command:** `swift run PersonaMode --probe render border /tmp/v2_border.png --w 800 --h 520 --scale 2`
- **`png-stats`:**
  ```json
  {
    "alphaCoveragePct": 92.46,
    "bbox": [24, 24, 1575, 1015],
    "cornerAlphaPct": [0, 0, 0, 0],
    "cyanPct": 1.67,
    "navyPct": 97.53,
    "whitePct": 0.09,
    "w": 1600,
    "h": 1040
  }
  ```
- **Rubric Verification (`§12.4 Border`):**
  - [x] **Four chamfered corner brackets:** `bracketsLayer` renders 4 chamfered L-brackets (`(0,0)→(L,0)→(L−4,T)→(T,T)→(T,L−4)→(0,L)`) mirrored at all 4 outer corners with `#00d8ff` fill and 1px `#ffffff` stroke.
  - [x] **Thin frame between brackets:** `frameShapeLayer` draws a continuous 2pt `#00d8ff` rounded-rect frame connecting the 4 corner brackets.
  - [x] **Visible two-tone glow (cyan near, royal blue far):** `glowInnerLayer` (`#00d8ff`, radius 6) and `glowOuterLayer` (`#0051ff`, radius 18) produce a bright cyan core halo transitioning into a deep royal-blue outer aura.
  - [x] **White corner ticks:** `ticksLayer` renders four `3.5×3.5` `#ffffff` square ticks just outside the 4 bracket corners.
  - [x] **Ring sits outside the dummy window edge (no overlap with its content):** The synthetic window (`#0a192f` body + `#050c1a` titlebar) is clipped inside `targetWinFrameAppKit` while the border ring is outset by `borderWidth / 2`, leaving the window interior completely untouched.


---

## 3. Desktop HUD, Layered Wallpaper & Composite (`v2_hud.png`, `v2_hud_darkhour.png`, `v2_wallpaper.png`, `v2_composite.png` — Phase V2.4)

### Iteration 1 → 2 Refinement
- **Iteration 1 Findings:** `cyanPct` on `/tmp/v2_hud.png` was `6.92%` (below the `>= 8%` rubric bound because `.wp-slash--1` used a royal-blue midpoint gradient), `Resources/wallpaper/p3r_wallpaper.png` was `9.2 MB` due to 2-bit LSB CoreGraphics gradient dither noise at 3840×2160, and `moon-countdown` in Dark Hour (`FULL // DARK HOUR`) wrapped onto two lines inside the 128×30 chip.
- **Iteration 2 Fixes:** Changed `.wp-slash--1` to solid `var(--cyan)` at `opacity: 0.94` (`cyanPct` rose to `13.60%`), wired `moon.countdown` (`T-05D 14H` in daytime, `FULL MOON` in Dark Hour) cleanly on a single line, and stripped 3-bit LSB dither noise on 4K exports so `Resources/wallpaper/p3r_wallpaper.png` compresses losslessly to `2.8 MB` (3840×2160 RGBA PNG).

### `png-stats` Output (Iteration 2 — Accepted)
- **`/tmp/v2_hud.png` (1512×982):** `{"alphaCoveragePct": 100.0, "cyanPct": 13.6, "navyPct": 44.84, "whitePct": 2.39}` (Rubric bounds: `cyanPct >= 8%`, `navyPct >= 25%` — **PASS**)
- **`/tmp/v2_hud_darkhour.png` (1512×982):** `{"alphaCoveragePct": 100.0, "cyanPct": 12.78, "navyPct": 48.87, "whitePct": 2.14}` — **PASS**
- **`/tmp/v2_wallpaper.png` (1512×982):** `{"alphaCoveragePct": 100.0, "cyanPct": 12.45, "navyPct": 41.5, "whitePct": 0.39}` — **PASS**
- **`/tmp/v2_composite.png` (1512×982):** `{"alphaCoveragePct": 100.0, "cyanPct": 13.99, "navyPct": 43.71, "whitePct": 2.64}` — **PASS**

### §12.4 HUD & Wallpaper Rubric Checklist
- [x] **Date numerals read `11 / 05`, three visible layers (white / navy outline / cyan back):** `11` (150px Bebas) and `05` (240px Bebas) render with `#ffffff` face, 10px `#050c1a` stroke mid-layer at `(5px, 5px)`, and `#00d8ff` back copy at `(10px, 10px)` separated by a 220px skewed cyan `/`.
- [x] **`THU` badge overlaps numerals, tilted:** 112×38 `.s-para` white badge with `#050c1a` text and `(5px, 5px)` cyan backing plate sits at `rotate(-4deg)` overlapping the bottom-right of `05`.
- [x] **Banner reads `AFTER SCHOOL` (fixture 16:30):** 420×52 `.s-tab-right` navy banner with 3px white top border, 2px cyan bottom border, and `▸ AFTER SCHOOL` in 36px Bebas Neue.
- [x] **Moon ring with 12 notched segments + 6 chambers + phase disc:** `moon-ring.svg` renders the 12-segment outer cylinder (`r=88`, `stroke-dasharray="38.07 8"`), 6 revolver chambers (`r=14`), 24 outer degree ticks, counter-rotating inner ring, and the waxing gibbous (`p=0.32`) terminator-ellipse SVG `<path>` computed by `moon.js`.
- [x] **`NEXT FULL MOON T-xxD xxH` chip:** 128×30 `.s-para` chip beneath the moon ring displays `NEXT FULL MOON` and `T-05D 14H` (`FULL MOON` in Dark Hour).
- [x] **Now-playing: jagged white back plate offset ≥ 5 px, vinyl, wings, title, artist chip, equalizer bars with different heights:** Bottom-left 460×176 `.s-jag` frame displays a 6px white offset plate, 3px ink mid-plate, navy face with cyan inner polygon border, 112px grooved vinyl + 140px angular wings, `COLOR YOUR NIGHT`, cyan parallelogram chip `AZUMI TAKAHASHI · LOTUS JUICE`, and 28 seeded equalizer bars with 25% mirrored reflection.
- [x] **Wallpaper shows ocean bands, giant moon, ≥ 3 diagonal slashes, halftone, outline typography:** L0–L8 render 6 sine-wave ocean bands, 44vmin radial moon + original angular Tartarus spire silhouette, 4 diagonal slashes (`#00d8ff` with crisp white upper edge), radial-masked halftone dot matrix, `MEMENTO MORI` / `DARK HOUR` 2px stroke typography, rising specular bubbles, and rotating HUD rings.
- [x] **Nothing overlaps the top-bar zone (top 50 px of HUD content region empty of widgets):** All HUD widgets start below `y = 66px`, leaving the 44px top bar completely unobstructed in `/tmp/v2_composite.png`.
- [x] **Dark Hour variant is clearly teal-green:** `/tmp/v2_hud_darkhour.png` shifts all slashes, moon disc, revolver ring, date back-plates, and equalizer bars to Tartarus emerald (`#00ff88` / `#5dffcf` / `#042420`).
