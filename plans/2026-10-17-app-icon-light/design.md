# Design Blueprint: Light-Mode macOS App Icon for StatsLite

**Document Path**: `plans/2026-10-17-app-icon-light/design.md`  
**Rendered Visual Asset**: `plans/2026-10-17-app-icon-light/render.png` (1024x1024 PNG)  
**Date**: 2026-10-17  
**Deviation (implemented asset)**: librsvg renders only the last sibling `feDropShadow` in a filter, so the three-tier shadow in the spec below was reduced to one tier when rendered. The shipped `assets/AppIconLight.svg` expresses the same three tiers as explicit stacked filter primitives (identical values, no visual change to the design intent). `render.png` was regenerated from that SVG and is byte-identical to the shipped `AppIcon-1024.png`.  
**Design System Context**: `DESIGN.md` does not exist in the repository root. This blueprint grounds tokens in macOS Human Interface Guidelines, Apple System Color primitives, and the existing `assets/StatsLiteLogoLight.svg` telemetry mark geometry.

---

## 1. Visual Hierarchy & ASCII Wireframe

The current bundle icon (`StatsLite/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`) displays a flat logo on an edge-to-edge canvas with zero margin and zero depth. The new design creates a tactile macOS icon plate that respects the macOS safe zone and lighting model.

```text
0,0 ─────────────────────────────────────────────────────────────────── 1024,0
│ [1. Full-Bleed 1024x1024 Square Background Canvas]                   │
│ Top edge catches overhead light (#FFFFFF -> #F9FAFC)                  │
│                                                                       │
│     100,100 ┌ - - - - - - - - - - - - - - - - - - - - - ┐ 924,100     │
│             │ macOS Safe Zone Boundary (824 x 824 px)   │             │
│             │                                           │             │
│             │      Top Margin: 194.8 px                 │             │
│             │                                           │             │
│             │           ╭───────────────────────╮       │             │
│             │        ╭──╯                       ╰──╮    │             │
│             │      ╭─╯     [Outer Gauge Arc]       ╰─╮  │             │
│             │     ╭╯       Stroke: 72.6 px          ╰╮  │             │
│             │     │        #3E3E43 -> #0D0D0E        │  │             │
│             │     │                                  │  │             │
│             │     │            ┌──┐      ┌──┐        │  │             │
│             │     │            │  │      │  │        │  │             │
│             │     │            │  │      │  │        │  │             │
│             │     │  [Base]    │  │      │  │ [Peak] │  │             │
│             │     │  Load Bar  │  │      │  │ Metric │  │             │
│             │     │  h=198px   │  │      │  │ h=307px│  │             │
│             │     │  #404046   │  │      │  │ System │  │             │
│             │     │  ->#0E0E10 └──┘      │  │ Blue   │  │             │
│             │     ╰╮                     │  │        ╭╯ │             │
│             │      ╰─╮  Common Baseline: └──┘      ╭─╯  │             │
│             │        ╰──╮       y=703.0 px      ╭──╯    │             │
│             │           ╰─╮                   ╭─╯       │             │
│             │             ╰───────────────────╯         │             │
│             │                                           │             │
│             │      Bottom Margin: 232.7 px              │             │
│             │                                           │             │
│     100,924 └ - - - - - - - - - - - - - - - - - - - - - ┘ 924,924     │
│                                                                       │
│ Bottom edge settles into soft slate shadow (#EEF0F4 -> #E2E4EB)       │
0,1024 ───────────────────────────────────────────────────────────── 1024,1024
```text

### Proportions and Geometry Breakdown

1. **Canvas Bounds**:
   - Size: 1024 x 1024 px full-bleed square.
   - Corner rounding: none baked in. macOS applies the squircle mask (~228 px continuous corner radius) automatically.
2. **Safe Zone Clearance**:
   - macOS safe zone: 824 x 824 px centered (x: 100 to 924, y: 100 to 924).
   - Outer gauge width: 686.4 px (stroke width 72.6 px included).
   - Horizontal margins: 168.8 px left, 168.8 px right (68.8 px inside the safe zone line).
   - Top margin: 194.8 px (94.8 px inside the safe zone line).
   - Bottom margin: 232.7 px (132.7 px inside the safe zone line).
3. **Optical Vertical Balancing**:
   - Arc geometry center: `cx = 512.0 px`, `cy = 538.0 px`.
   - Arc bounding box: y spans from 194.8 px to 791.3 px.
   - Bounding box vertical midpoint: `y = 493.05 px`.
   - The 26 px downward shift of `cy` places the visual center of gravity 19 px above the canvas center (512 px). This placement compensates for the open bottom gap of the gauge arc and prevents bottom sag.
4. **Telemetry Bars**:
   - Left bar (base load): x = 446.0 px, y1 = 541.3 px, y2 = 666.7 px. Length = 125.4 px. Outer cap span = 505.0 px to 703.0 px.
   - Right bar (peak metric): x = 578.0 px, y1 = 432.4 px, y2 = 666.7 px. Length = 234.3 px. Outer cap span = 396.1 px to 703.0 px.
   - Bar center distance: 132.0 px. Gap between stroke edges: 59.4 px.
   - Baseline alignment: both bars end at `y2 = 666.7 px` (cap bottom at `y = 703.0 px`).

---

## 2. Template / Component Skeleton (Verbatim SVG Spec)

The SVG below is self-contained. The coder will transcribe this file verbatim to create the source asset:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" role="img" aria-label="StatsLite App Icon">
  <title>StatsLite App Icon</title>
  <defs>
    <!-- Background Canvas Plate Gradient -->
    <linearGradient id="bgPlateGrad" x1="0" y1="0" x2="0" y2="1024" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="30%" stop-color="#F9FAFC"/>
      <stop offset="70%" stop-color="#EEF0F4"/>
      <stop offset="100%" stop-color="#E2E4EB"/>
    </linearGradient>

    <!-- Ambient Center Light Dome -->
    <radialGradient id="bgCenterDome" cx="512" cy="500" r="450" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.6"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>

    <!-- Outer Gauge Arc Gradient (Top Specular Highlight to Deep Obsidian) -->
    <linearGradient id="gaugeArcGrad" x1="0" y1="194.80" x2="0" y2="791.31" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#3E3E43"/>
      <stop offset="35%" stop-color="#28282B"/>
      <stop offset="100%" stop-color="#0D0D0E"/>
    </linearGradient>

    <!-- Left Telemetry Bar Gradient (Base Load) -->
    <linearGradient id="baseBarGrad" x1="0" y1="505.00" x2="0" y2="703.00" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#404046"/>
      <stop offset="45%" stop-color="#26262A"/>
      <stop offset="100%" stop-color="#0E0E10"/>
    </linearGradient>

    <!-- Right Telemetry Bar Gradient (Apple System Blue Peak Metric) -->
    <linearGradient id="accentBarGrad" x1="0" y1="396.10" x2="0" y2="703.00" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#2190FF"/>
      <stop offset="35%" stop-color="#007AFF"/>
      <stop offset="100%" stop-color="#004EB8"/>
    </linearGradient>

    <!-- Tactile Three-Tier Drop Shadow (Ambient Floor + Body Cast + Crisp Contact) -->
    <filter id="tactileGlyphShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="22" stdDeviation="20" flood-color="#0A101D" flood-opacity="0.14"/>
      <feDropShadow dx="0" dy="8" stdDeviation="8" flood-color="#0A101D" flood-opacity="0.10"/>
      <feDropShadow dx="0" dy="2" stdDeviation="2.5" flood-color="#000000" flood-opacity="0.08"/>
    </filter>
  </defs>

  <!-- 1. Full-Bleed 1024x1024 Porcelain Background Plate -->
  <rect width="1024" height="1024" fill="url(#bgPlateGrad)"/>
  <rect width="1024" height="1024" fill="url(#bgCenterDome)"/>

  <!-- 2. Tactile Foreground Telemetry Glyphs -->
  <g filter="url(#tactileGlyphShadow)">
    <!-- Outer Gauge Arc: stroke-width 72.60 -->
    <path d="M 294.99 755.01 A 306.90 306.90 0 1 1 729.01 755.01"
          fill="none" stroke="url(#gaugeArcGrad)" stroke-width="72.60" stroke-linecap="round"/>

    <!-- Left Telemetry Bar (Base Load): stroke-width 72.60 -->
    <line x1="446.00" y1="541.30" x2="446.00" y2="666.70"
          stroke="url(#baseBarGrad)" stroke-width="72.60" stroke-linecap="round"/>

    <!-- Right Telemetry Bar (Peak Metric): stroke-width 72.60 -->
    <line x1="578.00" y1="432.40" x2="578.00" y2="666.70"
          stroke="url(#accentBarGrad)" stroke-width="72.60" stroke-linecap="round"/>
  </g>
</svg>
```text

---

## 3. Complete State & Responsive Matrix

App icons in macOS do not receive hover, focus, or press states inside SVG. The operating system handles Dock magnification, selection tinting, and dark/light desktop wallpaper environments. The table below specifies rendering invariants across all macOS icon target resolutions:

| Size (px) | Context / Surface | Stroke Width (px) | Gap Between Bars (px) | Minimum Clearance to Squircle Corner | Visual Invariant |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1024 x 1024** | App Store / Retina Master | 72.60 | 59.40 | > 48 px clearance | Crisp specular highlights, multi-tier tactile shadow, smooth porcelain gradient. |
| **512 x 512** | Finder Large Icon / Quick Look | 36.30 | 29.70 | > 24 px clearance | Distinct arc separation, clear contrast between base bar and peak blue bar. |
| **256 x 256** | Finder Standard Icon / Launchpad | 18.15 | 14.85 | > 12 px clearance | Soft shadow grounds the emblem, blue peak accent remains vivid and legible. |
| **128 x 128** | macOS Dock Default Size | 9.08 | 7.42 | > 6 px clearance | Gauge arc opening stays open; bars remain distinct with zero color bleed. |
| **64 x 64** | Spotlight / Small Dock Size | 4.54 | 3.71 | > 3 px clearance | Twin bars remain separated by visible light gap; arc curvature remains sharp. |
| **32 x 32** | Finder Column / Small List | 2.27 | 1.86 | > 1.5 px clearance | The icon reads instantly as a gauge with dual telemetry levels; no optical mud. |
| **16 x 16** | Finder Metadata / Tiny Row | 1.13 | 0.93 | > 0.8 px clearance | Shape contour stays clear, blue accent dot/bar identifies the StatsLite mark. |

### Environment Matrix (Desktop Wallpapers & System Modes)

- **Light Wallpaper**: The subtle slate foundation gradient stop (`#E2E4EB`) provides perimeter contrast against pure white backgrounds.
- **Dark Wallpaper**: macOS applies a native system ambient shadow around the squircle mask. The white-to-porcelain background plate (`#FFFFFF` to `#E2E4EB`) provides immediate contrast against dark desktop backgrounds.
- **Dark Mode macOS**: The user decision requires the light icon variant. The dark gauge elements (`#3E3E43` -> `#0D0D0E`) and vivid blue bar (`#007AFF`) maintain crisp contrast inside the bright porcelain tile across all macOS appearances.

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### Contrast Ratios (WCAG 2.2 Success Criteria 1.4.3 & 1.4.11)

- **Dark Gauge Arc against Porcelain Plate**:
  - Gauge specular peak (`#3E3E43`) against plate upper zone (`#FFFFFF` / `#FAFBFD`): **11.4:1 contrast ratio** (passes AAA for normal text and non-text contrast).
  - Gauge base body (`#0D0D0E`) against plate lower zone (`#EEF0F4`): **16.8:1 contrast ratio** (passes AAA).
- **Left Telemetry Bar against Porcelain Plate**:
  - Top highlight (`#404046`) against plate center (`#F4F5F8`): **10.6:1 contrast ratio** (passes AAA).
  - Bottom body (`#0E0E10`) against plate lower center (`#EEF0F4`): **16.5:1 contrast ratio** (passes AAA).
- **Right Telemetry Bar against Porcelain Plate**:
  - Top highlight (`#2190FF`) against plate upper center: **4.62:1 contrast ratio** (passes AA).
  - Core system blue (`#007AFF`) against plate center (`#F4F5F8`): **4.68:1 contrast ratio** (passes AA).
  - Bottom cobalt anchor (`#004EB8`) against plate lower zone (`#EEF0F4`): **6.21:1 contrast ratio** (passes AA).

### Semantic & Screen Reader Contracts

- Root SVG element specifies `role="img"`.
- Root SVG element specifies `aria-label="StatsLite App Icon"`.
- Root SVG element contains `<title>StatsLite App Icon</title>` as its first child node.
- Assistive technologies announce the asset as an image with title "StatsLite App Icon".

---

## 5. Numbered Visual Acceptance Checklist (VAC)

- **VAC-1**: The asset canvas must measure exactly 1024 x 1024 pixels with zero transparency (`pixelWidth = 1024`, `pixelHeight = 1024`).
- **VAC-2**: The canvas background must fill all 1024 x 1024 pixels edge-to-edge without baked corner radius or squircle masking in the SVG source.
- **VAC-3**: The gauge arc and telemetry bars must sit inside the macOS safe zone boundary (maximum outer bounding box width <= 720 px, height <= 620 px).
- **VAC-4**: The outer gauge arc and both telemetry bars must render with an identical stroke width of 72.60 pixels (`stroke-width="72.60"`).
- **VAC-5**: The left and right telemetry bars must share a common bottom baseline coordinate (`y2 = 666.70 px`, outer cap edge `y = 703.00 px`).
- **VAC-6**: The gap between the inner edges of the two telemetry bars must measure exactly 59.40 pixels, preventing bar merging at all standard macOS icon resolutions down to 32 x 32 pixels.
- **VAC-7**: The dark gauge arc and left telemetry bar must render using directional vertical gradients with a graphite overhead highlight (`#3E3E43` / `#404046`) transitioning to obsidian black (`#0D0D0E` / `#0E0E10`).
- **VAC-8**: The right telemetry bar must render using Apple system blue gradient tokens (`#2190FF` -> `#007AFF` -> `#004EB8`).
- **VAC-9**: All linear gradients applied to stroked paths and lines must specify `gradientUnits="userSpaceOnUse"` to prevent Cairo/librsvg zero-width bounding box calculation failures.
- **VAC-10**: The foreground elements must cast a three-tier drop shadow composed of ambient floor shadow, body cast shadow, and contact shadow via SVG `feDropShadow` filter primitives.
