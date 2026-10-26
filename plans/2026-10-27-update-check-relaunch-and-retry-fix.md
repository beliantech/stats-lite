# Plan: update-check relaunch and retry fix

Plan name: `2026-10-27-update-check-relaunch-and-retry-fix`
Date: 2026-10-27
Risk class: **R1** (normal behavior change, one file plus tests, no UI/schema/API change)

## Intent

Fix two defects in `StatsLite/UpdateCheckService.swift` found by the Oracle diagnosis of the "update available" mechanism (user report: mechanism seems broken; verdict: pipeline works, but the service loses state and blocks retries).

1. **Relaunch amnesia**: `updateCheckLastCheckEpoch` persists in `UserDefaults`, but `availableUpdate` is memory-only. A relaunch within 300 s (`launchCheckMinGap`) skips `performCheck()`, so the new process shows no banner for 24 h even when a newer release exists.
2. **Premature epoch stamp**: `performCheck()` writes `updateCheckLastCheckEpoch` before `source.latestRelease()` returns. A launch-time network failure (for example, Wi-Fi still associating at login) stamps the epoch and blocks any retry for 300 s, then 24 h.

Scope boundary: this is the minimal surgical patch (Oracle Option B) while the custom GitHub poller stays in production. It does not add UI, does not touch `UpdateBannerCardView`, and does not overlap the parked Sparkle 2 design (`plans/2026-10-26-macos-auto-update/design.md`).

## ISC (binary)

- [ ] **ISC-1** — `performCheck()` writes `updateCheckLastCheckEpoch` only after `latest` resolves to a non-nil `ReleaseInfo` (fixture release or successful `source.latestRelease()`). A nil network result with no fixture leaves the stored epoch unchanged.
- [ ] **ISC-2** — A relaunch in the launch-floor skip window (`0 <= gap < launchCheckMinGap`, no fixture override) restores `availableUpdate` from a cached release when `UpdateCheckPolicy.promptState` prompts (latest > current and not dismissed).
- [ ] **ISC-3** — Dismissal still wins across relaunch: if the cached latest version is dismissed (`updateCheckDismissedVersion`), `availableUpdate` stays `nil` after the restore path.
- [ ] **ISC-4** — Fixture behavior unchanged: `STATSLITE_FAKE_UPDATE_VERSION` still bypasses the network and the launch floor, and the fixture path does not write the release cache (a fixture launch must never pollute the restore path of a later real launch). Existing `UpdateCheckFixtureFloorTests` / `UpdateCheckLaunchPolicyTests` pass unchanged except where they must learn the new cache key for cleanup.
- [ ] **ISC-5** — The 24 h background loop and the 300 s launch floor for successful checks are unchanged (no extra network traffic in steady state).
- [ ] **ISC-6** — All existing `UpdateCheck*` tests pass; typecheck and lint errors on changed files = 0.

Failure modes (each gets a red test in T1):

- **FM1** — Epoch stamped on failed fetch: `CountingReleaseSource` returns nil, no fixture env; after `performCheck()`, stored epoch is unchanged (still old/absent).
- **FM2** — Relaunch amnesia: service 1 checks with a newer release and sets `availableUpdate` (and writes the cache); service 2 starts within 300 s against the same `UserDefaults` and restores `availableUpdate` from cache.
- **FM3** — Dismiss-then-relaunch: cached latest = 9.9.9, `updateCheckDismissedVersion` = "9.9.9"; service restore path leaves `availableUpdate` nil.
- **FM4** — Epoch stamps on success: non-nil release result (fixture and network) still writes the epoch (guards against over-correcting FM1; keeps existing fixture-floor tests green).
- **FM5** — Stale cache with old release: cached latest = 1.0.0, current = 1.1.1; restore path does not prompt.
- **FM6** — Fixture cache pollution: fixture launch (env `STATSLITE_FAKE_UPDATE_VERSION=9.9.9`, current 1.1.1) leaves the release cache unchanged.
- **FM7** — Clock-skew skip: stored epoch in the future (`gap < 0`) still runs `performCheck()` and never takes the cache-restore path (existing skew behavior preserved).

## Approach

`UserDefaults` is **not** injected: the service reads and writes `UserDefaults.standard` directly (`UpdateCheckService.swift:57-58, 91-94, 100-105, 114-116`). The cache lives there too, next to the existing keys.

- **Cache format** (no model change; `ReleaseInfo` stays non-Codable and keeps only `version` + `releasePageURL`): new static key `updateCheckCachedLatestJSON = "updateCheckCachedLatest"` holding a two-field JSON object `{"tag_name": "9.9.9", "html_url": "https://..."}`. A private decode helper parses it with `JSONDecoder` into `ReleaseInfo` (SemanticVersion from `tag_name`, `URL` from `html_url`); any decode/parse failure is treated as a cache miss (nil, silent).
- **In `performCheck()`**: move the epoch stamp from the top to after `latest` resolves (fixture or non-nil fetch); write the cache **only** when `latest` came from the network (never from the fixture); on nil network result, leave epoch and cache untouched.
- **In `start()`**: on the skip path (`0 <= gap < launchCheckMinGap`, which by construction excludes the fixture override and the clock-skew `gap < 0` case, both of which already run `performCheck()`), decode the cache and run it through `UpdateCheckPolicy.promptState` with the current bundle version and stored dismissed version, then set/clear `availableUpdate` exactly like `performCheck()` does. Unparsable current version or missing/corrupt cache → `availableUpdate` stays nil (silent).
- **Test cleanup**: existing `UpdateCheck*` tests clean `UserDefaults.standard` via hardcoded key arrays; add `updateCheckCachedLatest` to those arrays so the cache never leaks between tests.
- No UI change. No status-item or popover change. `UpdateBannerCardView` untouched.

## Refactors

None required. No band-aids touched; `StatSLITE_FAKE_UPDATE_VERSION` fixture key stays as-is.

## Tasks

- [ ] **T1** — red phase: failing tests for FM1–FM7 in the `UpdateCheck*` test files, plus the new cache key in every `UserDefaults` cleanup array. red ⏳ · green n/a · review ⏳
- [ ] **T2** — green phase: implement the epoch-stamp move + network-only cache write + skip-path restore in `StatsLite/UpdateCheckService.swift` until FM1–FM7 pass and the full suite is green. red n/a · green ⏳ · review ⏳
