# Task 05 — Menu Bar Item & Popover UI

## Objective

3-slot menu bar item + popover with CPU / Memory Pressure / GPU cards, dynamic height.

## Read first (verbatim, follow specs)

- **Extension blueprint**: §1 wireframes + width table (COMB-1..7), §2 visual spec, §3 state matrix, §5 VAC-14..VAC-24 (yours), accessibility contracts.
- **Base blueprint** `notes.md`: tokens, CPU card, sparkline (38 pt, `Canvas`/`Path` — NO `import Charts`), header/footer, VAC-1..VAC-13 (shared items).
- ISC §Architecture: Concurrency & UI (MenuBarExtra `.window` style, `openSettings` activation), Footprint budget.

## Deliverables

1. App entry: `MenuBarExtra` (.window style) bound to `SystemMonitor` + `PreferencesStore`.
2. Menu bar label: only enabled slots; per COMB widths; `.monospacedDigit()`, `.fixedSize()`, `.lineLimit(1)`; RAM = 6 pt pressure dot + used %; GPU `--%` when nil; `·` separators only between adjacent active slots; `.contentTransition(.numericText())`.
3. Popover (width fixed 280 pt, `.regularMaterial`): header (Stats Lite + gear 24×24 + quit 24×24 with `.help`), cards for enabled metrics only, footer. Heights ≈390/300/210 collapsed (≈470/380/290 expanded cores), 200 ms ease-in-out transitions.
4. CPU card per base blueprint; **Memory Pressure card** per extension §2 (badge, **8 pt gauge bar**, sparkline, Used line, 4 pt composition bar, breakdown); **GPU card** per extension §2 incl. dashed unavailable state (38 pt, dash [4,4]).
5. Accessibility contracts from extension blueprint (composite label, dot label, sparklines hidden).
6. Escape/outside-click closes; gear → `NSApplication.shared.activate(ignoringOtherApps: true)` then `openSettings()`.

## Report

- Conventional commits, ≤2. Mark VAC-14..VAC-24 + shared VAC items Met/not with evidence; screenshots of: menu bar all-3 labeled/unlabeled, single-metric mode, popover 3 cards, GPU unavailable state (use a stubbed `nil` GPU if needed), Light + Dark.
