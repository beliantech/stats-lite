# Panel container anchor geometry — wave 2 measurements

Date: 2026-10-21 (Asia/Kuala_Lumpur). Branch `fix/panel-popover`, before the
first code edit. Plan `.pi/plans/2026-10-21-popover-panel-fix.json`, wave 2.
Evidence for behavior-checklist row 4 (`NEEDS-LIVE-CHECK`: exact offset of the
popover content rect) and for the panel corner radius (row 7).

## 1. Live NSPopover geometry (AppKit, ground truth)

A standalone AppKit script (`/tmp/popgeom.swift`, shown below in its final
form) shows a 280x560 content view in an `NSPopover` with
`preferredEdge: .minY` against a positioning rect that simulates the status
button, then prints screen rects. Verbatim output:

```text
buttonScreen      x 1500.00 y 701.00 w 140.00 h 22.00  (minY 701.00, midX 1570.00)
popover window    x 1417.00 y 115.00 w 306.00 h 586.00  (maxY 701.00, midX 1570.00)
content view frame in window: {{13, 13}, {280, 560}}  size 280.00x560.00
contentScreen     x 1430.00 y 128.00 w 280.00 h 560.00  (maxY 688.00, midX 1570.00)
GAP buttonMinY - contentMaxY = 13.00
GAP buttonMidX - contentMidX = 0.00
window insets vs content: left 13.00 right 13.00 bottom 13.00 top(with arrow) 13.00
window class: _NSPopoverWindow  styleMask raw: 0  isFloatingPanel: false  level: 25
after makeKey: isKeyWindow=false  NSApp.keyWindow===pw false  NSApp.isActive false
KEY CHECK: NSApp.isActive=false  pw.isKeyWindow=false  canBecomeKey=true  canBecomeMain=false
```

Facts used by the panel implementation:

- The popover content rect sits exactly **13.00 pt below** the positioning
  rect's `minY` edge (preferredEdge `.minY`). The panel anchor gap is 13.
- The content rect is **centered** on the button (horizontal offset 0.00).
- The popover window frame is the content rect expanded by 13 pt on all four
  sides. The arrow lives inside the top 13 pt band. The panel window equals
  the content rect (no band, arrow omitted per plan decision).
- `_NSPopoverWindow` reports `canBecomeKey = true`, `canBecomeMain = false`,
  `isFloatingPanel = false`. The panel mirrors `canBecomeKey` so the local
  Esc monitor can receive keyDown. `makeKey` was refused in this session
  (console locked, see section 3), so key status is a live check in wave 3.

## 2. Pre-fix baseline PNG geometry (`baseline/*.png`, dark and light)

Measured with an ImageIO pixel scan of `artifacts/2026-10-21-popover-panel-fix/baseline/dark.png`
(612x1194 px at 2x = 306x597 pt window capture) and cross-checked on `light.png`:

```text
window capture        306.0 x 597.0 pt
body (opaque)         x 13.0..292.5 pt -> width 280.0 pt, y 13.0..583.5 pt -> height 570.5 pt
margins               13.0 pt left/right/top/bottom (transparent; shadow band removed by -o)
top-left corner arc   starts at (30.5, 13.0), reaches (13.0, 30.0)
                      -> horizontal extent 17.5 pt, vertical extent 17.0 pt
arrow                 apex y ~1.5, base y 13.0 (11.5 pt tall), base width ~26 pt at body edge
edge luminance        body edge (39,39,38) vs interior (33,32,33): +6 rim from popover chrome
light.png             identical shape: body top 13.0, arc (30.5,13.0)->(13.0,30.0)
```

Corner radius verdict: the arc endpoints give radius 17.5 pt horizontal and
17.0 pt vertical, and the mid-arc points sit outside the matching circle, so
a **continuous corner of radius 17.5 pt** reproduces the silhouette. The
plan's "~13 pt, POPUP/menus style" was an unverified prior; the baseline
measurement wins. `PopoverPanel.cornerRadius = 17.5`.

The popover content height for that capture was 570.5 pt. The panel hook run
settles at 280x571 (see section 4), the same content size.

## 3. Session display state: global 0.9 window transform (wave-3 caveat)

During wave 2 the console session runs on a `Screen Sharing Virtual Display`
(1920x1080, backing scale 2, menu bar 30 pt) with `loginwindow` frontmost.
While this state is active, **every window of every process reads back 0.9x
its AppKit frame from `CGWindowList`**, scaled about the screen center:

```text
CG' = 0.9 * CG + (0.1 * screenWidth, 0.1 * screenHeight)
    = 0.9 * CG + (96, 54)
```

Evidence that this is environmental, not panel code:

- A plain titled `NSWindow` (no panel, no hosting controller) shows the same
  map: AppKit `280x532` -> CG `252x479`.
- The user's Terminal window reads `1063x559` in CG bounds; under the map its
  AppKit width would be 1181.1 pt (plausible for a drag-resized window).
- The map holds in a clean environment (`env -i swift ...`).
- The probe run at 07:44 (step3b: CG `w=280 h=560`, exact) and the wave-1
  baseline PNGs (commit 18d4b25 at 08:27, popover window exactly 306 pt)
  predate this state, so the state changed after 08:27.

Inverse-mapping the panel's hook-run reading confirms the panel geometry:

```text
CG panel bounds      x=1296 y=89 w=253 h=514
inverse (x-96)/0.9   x=1333.3, w=281.1, h=571.1
AppKit frame (log)   280x571, x = buttonMidX - 140 = 1334 (probe-era button center)
```

Wave-3 rule: while `NSScreen.main.localizedName` reads
`Screen Sharing Virtual Display`, multiply CG window bounds by 1/0.9 to
compare with AppKit geometry, or re-run on the physical display.

## 4. Panel hook dry run (Debug build, `--open-popover --popover-cycles 1 --popover-hold 8`)

Verbatim excerpt (full log stderr, gated `[measurement]` validity lines):

```text
[measurement] 1792546485.464 cycle 1/1 open
[measurement] 1792546485.506 panel open fitted 280x538 preferred 0x0
[measurement] 1792546485.509 panel did show frame 280x538
[measurement] 1792546486.569 ideal change 280x571
[measurement] 1792546487.559 panel frame now 280x571 contentFitting 280x571
[measurement] 1792546493.813 cycle 1/1 close
[measurement] 1792546493.815 panel did close
[measurement] 1792546493.817 cycles complete
```

All five markers the harness needs are present. The harness parses only lines
whose third field is `cycle` (`scripts/measure_popover_footprint.sh:148`),
so the extra validity lines do not change event matching. The content starts
at the pre-data ideal (280x538) and settles at 280x571 with top-anchored
growth, matching the 570.5 pt baseline content height.

## 5. Panel window state while open (CG dump, current session)

```text
win 14343 layer 101 bounds x=1296 y=89 w=253 h=514
```

Layer 101 = `.popUpMenu`, above other windows (checklist row 6). Bounds are
0.9-scaled by section 3; the inverse map gives the exact 280x571 panel frame
below the status button. The panel closes fully after the cycle (no window
left in the post-close dump).
