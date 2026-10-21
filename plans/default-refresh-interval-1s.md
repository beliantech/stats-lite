# Plan: Default refresh interval 1s on first launch

## Goal
On first launch (no stored `refreshInterval`), the app refreshes every 1 second instead of 2.

## Current state
The first-launch default is 2 seconds, defined in three places plus a test:
- `StatsLite/PreferencesStore.swift:63` — `var refreshInterval: Int = 2`
- `StatsLite/PreferencesStore.swift:117` — `@AppStorage("refreshInterval") ... = 2`
- `StatsLite/SystemMonitor.swift:34` — `var refreshInterval: TimeInterval = 2.0` (fallback before `apply`)
- `StatsLiteTests/PreferencesStoreGuardTests.swift:55` — asserts default is 2

## Target state
All four sites use 1 (or 1.0). The settings picker already offers 1s, 2s, 3s, 5s (`StatsLite/SettingsView.swift:49`), so no picker change is needed.

## Steps
1. Edit `PreferencesStore.swift:63` and `:117`: default `2` → `1`.
2. Edit `SystemMonitor.swift:34`: default `2.0` → `1.0`.
3. Edit `PreferencesStoreGuardTests.swift:55`: expectation `2` → `1`.
4. Build the macOS app target and run the `PreferencesStoreGuardTests` suite.

## Verification
- Build succeeds.
- The guard test asserting the first-launch default passes with value 1.

## Risks
- Existing users with a stored `refreshInterval` are unaffected (key present).
- Network sample loop stays fixed at 1.0s; unrelated to this change.
