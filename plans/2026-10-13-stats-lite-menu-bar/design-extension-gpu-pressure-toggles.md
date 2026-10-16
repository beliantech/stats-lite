# Design Blueprint Extension — 3-Metric Menu Bar, Memory Pressure, GPU Card, Visibility Toggles

Source: `designer` consult, 2026-10-15. Extends the base blueprint in `notes.md` (VAC-1..VAC-13 → new VAC-14..VAC-24). Visual source of truth for tasks that touch GPU, pressure, or toggles; the base `notes.md` remains authoritative for unchanged elements.

## 1. Layout & Wireframes

### Menu bar item (height 22 pt)

```
All 3 enabled, labels on:   CPU 14%  ·  RAM ● 62%  ·  GPU 28%      ~200 pt
All 3 enabled, labels off:  14%  ·  ● 62%  ·  28%                  ~129 pt
GPU unavailable (labels on): CPU 14%  ·  RAM ● 62%  ·  GPU --%     (~200 pt)
```

2-metric widths (labels on / off): CPU+RAM 134/87 pt · CPU+GPU 125/78 pt · RAM+GPU 135/87 pt.
1-metric widths (labels on / off): CPU 59/36 pt · RAM 69/45 pt · GPU 60/36 pt.

Width formula: `8 (container padding) + slots + 14 per separator`. Slot: label 21-22 pt + 2-3 pt gap; percentage slot 28 pt max (`100%`); RAM dot 6 pt + 3 pt gap. All numerals `.monospacedDigit()`, `.fixedSize()`, `.lineLimit(1)` — zero jitter from `9%`→`100%`.

Separator `·` renders only between adjacent active metric slots; absent in single-metric mode.

### Popover (fixed width 280 pt, dynamic height)

```
Header (28 pt):  [gauge] Stats Lite            [gear 24x24] [power 24x24]
Divider (1 pt)
  CPU CARD            (if showCPU)   — base blueprint card, unchanged
  MEMORY PRESSURE CARD (if showRAM)  — reworked, see below
  GPU CARD            (if showGPU)   — new, see below
Divider (1 pt)
Footer (22 pt):  Updated every 2s                    macOS Native
```

Dynamic heights (collapsed cores / expanded 8-core grid):
- 3 cards: **~390 pt / ~470 pt**
- 2 cards: **~300 pt / ~380 pt**
- 1 card: **~210 pt / ~290 pt**

Card visibility transitions animate ease-in-out, 200 ms.

**Memory Pressure card** (top→bottom): header row `[memorychip] Memory Pressure` + trailing capsule badge (`Normal`/`Warning`/`Critical`, tinted fill 0.15 + 0.5 pt stroke 0.3, colored text, size 10 semibold) → pressure gauge bar (**8 pt height — authoritative per VAC-21**, continuous 3 pt radius, track = separator 0.2, fill = level color, width = pressure fraction) → sparkline 38 pt, tint = level color → `Used: 62% (9.9 / 16.0 GB)` monospaced 11 pt → segmented composition bar (App blue, Wired purple, Compressed orange, Free quaternary, 4 pt rounded container, height 6 pt) → breakdown text `App: 5.2G · Wired: 2.8G · Comp: 1.9G` size 10 tertiary.

**GPU card**: header `[display] GPU Usage` + value (`24.0%`, 12 bold rounded monospaced, or `--%` tertiary when nil) → subtitle GPU name (`Apple M2 Pro (16 cores)` fallback `Integrated Graphics`, size 10 tertiary) → sparkline 38 pt, tint teal.

**GPU unavailable state**: header value `--%`; content = `Unavailable` (size 10 tertiary) → 38 pt dashed container (continuous 4 pt radius, separator 0.6, dash `[4,4]`) containing `exclamationmark.triangle` + `GPU metrics unavailable on this hardware` (10 pt secondary) → footnote `Sampling requires Apple Silicon or supported Metal driver.` (9.5 pt tertiary, ≤2 lines).

### Settings window (380 × 340 pt, `.formStyle(.grouped)`)

```
General            — Refresh Interval picker (1/2/5 s), Launch at Login toggle
Visible Metrics    — CPU Utilization [toggle]
                     Memory Pressure (RAM) [toggle]
                     GPU Utilization [toggle]
                     footer: At least one metric must remain enabled.
Display Options    — Show Category Labels, Show Per-Core CPU View, History Duration (30/60 s)
Footer             — Stats Lite v1.0.0 (Build 1)
```

(The base blueprint's "display format both/CPU-only/RAM-only" picker is replaced by the three metric toggles; the RAM Unit setting is removed — popover shows GB, menu bar shows used %.)

## 2. Visual Spec

Tokens reused from `notes.md:129-465`: card = continuous 8 pt radius, 0.5 pt separator border, controlBackground 0.65 fill, 10 pt padding; sparklines 38 pt, no axes; popover material = native `.regularMaterial`.

- Labels: SF Pro Text 10 pt semibold, secondary. Values: 11.5 pt medium `.monospacedDigit()`. Separator `·` 10 pt bold tertiary.
- Pressure colors: `systemGreen` (normal) / `systemYellow` (warning) / `systemRed` (critical), as `Color(nsColor:)`.
- GPU tint: system teal. Header buttons: 24×24 pt hit targets, `.contentShape(Rectangle())`, `.buttonStyle(.plain)`, `.help(...)`.
- Menu bar RAM dot: 6 pt circle, colored by level, `.help("Memory Pressure: <level>")`.
- Unavailable numerals: `--%` in `.tertiary`.

## 3. State Matrix

| Component | State | Treatment |
| --- | --- | --- |
| Menu bar RAM dot | Normal / Warning / Critical | 6 pt filled circle green / yellow / red |
| Menu bar GPU slot | Available / Unavailable | `28%` monospaced / `--%` tertiary |
| Popover RAM badge | Normal / Warning / Critical | Capsule pill, tinted fill 0.15 + stroke 0.3, colored text |
| Popover RAM gauge | any level | 8 pt bar, fill width = pressure fraction, color = level color |
| Popover GPU card | Available | Teal 38 pt sparkline |
| Popover GPU card | Unavailable | `--%` + 38 pt dashed container + caveat footnote |
| Settings metric toggle | ≥2 active | Normal interactive switch |
| Settings metric toggle | 1 active (its own) | `.disabled(true)`, switch locked ON, footer caption visible |

Pressure thresholds (Activity Monitor): Normal <60 %, Warning 60–80 %, Critical >80 % of the pressure figure (oracle fixes the exact source; thresholds apply to the 0–1 pressure value).

## 4. Interaction Rules

1. **Toggles** control menu bar slot AND popover card together; popover height animates on change (200 ms ease-in-out).
2. **Last-one-enabled guard**: when `activeMetricCount == 1`, the sole ON toggle gets `.disabled(true)`. Model-level guard in `PreferencesStore`:
   ```swift
   var activeMetricCount: Int { (showCPU ? 1 : 0) + (showRAM ? 1 : 0) + (showGPU ? 1 : 0) }
   var showCPU: Bool = true { didSet { if !showCPU && activeMetricCount == 0 { showCPU = true } } }
   ```
   On init, if all three defaults keys are false, reset `showCPU = true`.
3. Settings gear: `NSApplication.shared.activate(ignoringOtherApps: true)` before `openSettings()` (LSUIElement).
4. Escape / outside click closes popover (base blueprint).
5. Disabled metrics are not sampled (oracle fixes the mechanism).

## 5. Visual Acceptance Checklist (extends VAC-1..VAC-13)

| ID | Invariant | Met |
| --- | --- | --- |
| VAC-14 | 3-metric mode renders CPU, RAM, GPU on one line, zero wrapping, all resolutions | |
| VAC-15 | Menu bar widths match spec per combination (3 metrics 129/200 pt; 1 metric 36–69 pt) | |
| VAC-16 | RAM readout = 6 pt dot (green/yellow/red by level) + numeric used % | |
| VAC-17 | `·` separator centered between adjacent active metrics; absent with one metric | |
| VAC-18 | GPU card available: 8 pt radius, 0.5 pt border, 38 pt teal sparkline, matches CPU/RAM cards | |
| VAC-19 | GPU card unavailable: `--%`, 38 pt dashed container with warning icon + caveat | |
| VAC-20 | RAM card capsule badge shows Normal/Warning/Critical with matching tint/stroke | |
| VAC-21 | RAM card shows pressure gauge bar (8 pt) above the sparkline | |
| VAC-22 | Popover height adapts (≈390/300/210 pt collapsed; ≈470/380/290 expanded), width fixed 280 pt | |
| VAC-23 | Settings has "Visible Metrics" section with three independent toggles | |
| VAC-24 | Last active toggle renders disabled in ON position; footer caption visible | |

## Accessibility contracts

- Menu bar composite VoiceOver label: `"Stats Lite: CPU <n> percent, Memory Pressure <level> with <n> percent used, GPU <n|unavailable>"`.
- Dot: `.accessibilityLabel("Memory pressure is <level>")`; RAM card and GPU-unavailable states expose full descriptions; sparklines `.accessibilityHidden(true)`.
- Contrast: dot ≥3:1 vs menu bar; badge/unavailable text ≥4.5:1; targets ≥24×24 pt (buttons) and native switch sizes (toggles).
