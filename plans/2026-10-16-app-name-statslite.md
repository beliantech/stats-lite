# App Name: StatsLite, Not Stats Lite

## User story

As a user of the app, I see the name "StatsLite" (one word, camel case) everywhere the app
names itself, so the app has one consistent brand instead of two spellings.

## Current state (scout-verified)

Identifiers already use `StatsLite`: target, scheme, product name, `CFBundleName`,
`CFBundleExecutable`, bundle ID `com.beliantech.statslite`, module name, and the process
name matched by `scripts/`. Only the human-readable copy says "Stats Lite":

| File:line | Current string | Kind |
| --- | --- | --- |
| `StatsLite/PopoverContentView.swift:72` | `Text("Stats Lite")` | Popover header |
| `StatsLite/PopoverContentView.swift:101` | `.help("Quit Stats Lite")` | Tooltip |
| `StatsLite/SettingsView.swift:158` | `"Stats Lite v\(version) (Build \(build))"` | Settings footer |
| `StatsLite/StatusItemController.swift:194` | `setAccessibilityTitle("Stats Lite")` | VoiceOver title |
| `StatsLite/MenuBarAccessibility.swift:59` | `"Stats Lite: " + parts...` | VoiceOver label |
| `StatsLite/StatusItemController.swift:198` | `/// "Stats Lite: CPU 14 percent, ...` | Doc comment |

Tests that pin the old strings:
- `StatsLiteTests/MenuBarAccessibilityTests.swift` — 14 assertion lines (31, 47, 64, 80,
  94, 102, 108, 116, 125, 160, 180, 200, 219, 238), e.g. `"Stats Lite: CPU 50 percent"`.
- `StatsLiteTests/SettingsWindowTests.swift:137` — regex
  `#"^Stats Lite v[0-9][0-9.]* \(Build [0-9]+\)$"#`, and `:140` failure message.

Out of scope: bundle ID, target/product/scheme names, `@testable import StatsLite`,
script process matching, repo/branch/worktree directory names, `.pi/plans/` history,
and rendered baseline PNGs. None of these show "Stats Lite" to a user.

## Approach

One mechanical string sweep: replace "Stats Lite" with "StatsLite" in the five source
strings, the doc comment, and the test assertions/regex/message. No identifier, build
setting, or script change. No layout change (the string gets one character shorter).

## Tasks

- [x] 1. Update the five user-facing strings and the doc comment
       (`PopoverContentView.swift`, `SettingsView.swift`, `StatusItemController.swift`,
       `MenuBarAccessibility.swift`) from "Stats Lite" to "StatsLite".
- [x] 2. Update the test expectations in `MenuBarAccessibilityTests.swift` (14 lines) and
       `SettingsWindowTests.swift:137,140` to match the new strings.
- [x] 3. Verify: `rg -n "Stats Lite" StatsLite StatsLiteTests` returns zero hits;
       `xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS'`
       passes (this runs the VAC verification tests that pin the strings).
       Result: 198 tests, 0 failures.
- [x] 4. Reviewer GO, merge to `main` (`--ff-only`). Merged at c25d66d.

## Verification

`xcodebuild test` covers the string-pinning tests. A grep for the old string over
`StatsLite/` and `StatsLiteTests/` proves the sweep is complete.

## Risks

- Low. Pure string change; identifiers and build settings are untouched, so signing,
  process matching, and scripts are unaffected.
- The menu bar item itself shows metrics, not the app name, so no fixed-width or
  truncation risk. The popover header and settings footer widths shrink by one space
  character. Designer to confirm.
- Stale worktree `worktrees/2026-10-15-stats-lite-view-weight` still contains the old
  strings; it is already broken (prunable) and is not part of this change.

## Designer review

APPROVED WITH CHANGES (none). The repo has no root `DESIGN.md`; the governing design
rules are `.pi/plans/2026-10-13-stats-lite-menu-bar/notes.md` and `DesignTokens.swift`.

- Popover header: the `Spacer()` in the `HStack` absorbs the removed space (~3.3 pt).
  No wrap, truncation, or alignment shift. Hit targets stay >= 24x24 pt (VAC-9).
- Settings footer: centered text in a 380 pt window keeps >130 pt margin per side.
  Stays on one line.
- Menu bar: renders metric blocks, never the app name. The two a11y strings are
  VoiceOver metadata and do not participate in layout. Block widths stay 34/50 pt.

Implement the string replacements exactly as drafted.

## Status

DONE. Commit c25d66d (fix(branding): rename user-facing app name to StatsLite),
merged fast-forward into main. UI-UX review: GO. Worktree and branch cleaned up.
