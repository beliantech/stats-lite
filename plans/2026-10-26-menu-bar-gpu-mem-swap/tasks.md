# Tasks — Menu Bar GPU/MEM Positional Swap

Plan: `plans/2026-10-26-menu-bar-gpu-mem-swap/plan.md`. ISC: `isc.md`.
Worktree: `worktrees/2026-10-26-menu-bar-gpu-mem-swap`, branch `feat/2026-10-26-menu-bar-gpu-mem-swap`.
Convention: `red` = test-only commit that fails on current production. `green` = implementation commit that makes it pass. `v` = verified by the planner against git/ISC.

---

## T1 — Baseline capture + worktree

- [x] **T1** — display awake; run `scripts/capture_menubar.sh`; copy outputs to `artifacts/2026-10-26-menu-bar-gpu-mem-swap/before/`. Create worktree with `git worktree add -B feat/2026-10-26-menu-bar-gpu-mem-swap worktrees/2026-10-26-menu-bar-gpu-mem-swap main`.
- Failing test: none (mechanical).
- Stop condition: capture script fails or display asleep → fix environment first; no code edit until `before/` exists.
- Success checklist: `before/` has dark + light strips; worktree checked out; `git status` clean. Receipt in the Ledger (T1): script exit 0, strips are wallpaper-only (TCC), evidence in `before/capture-note.txt`.

## T2 — Red: order-expectation tests (production untouched)

One task = the full set of order expectations. All are failing tests on current production.

- [x] **T2** — rewrite every order expectation to `CPU → GPU → MEM` (no production edit, no constant value change except the cold-band renames of plan.md correction 1, which swap names only — values 17–20 and 11–14 stay):
  - `StatsLiteTests/MenuBarBlockBuilderTests.swift`: `:54` `["CPU","GPU","MEM"]`; `:55` `[.cpu,.gpu,.ram]`; `:73` comment; `:81` `[.gpu,.ram]`; `:82` `[.cpu,.gpu,.ram]`; `:250` `result[1]`; `:338` test name; `:349` `[.cpu,.gpu,.ram,.network]`; `:350` message; `:432` `[.gpu,.ram,.network]`.
  - `StatsLiteTests/MenuBarAccessibilityTests.swift`: `:31`, `:47`, `:64`, `:80`, `:160-161`, `:180-181`, `:238` — GPU phrase before Memory Pressure phrase.
  - `StatsLiteTests/MenuBarTempBlockTests.swift`: MARK `:179`, doc `:181-183`, name `:184`, kind arrays `:199-200` and `:219-221`, name `:210`, messages `:196`, `:201-204`, `:222`.
  - `StatsLiteTests/MenuBarTempVerificationTests.swift`: append order `:223-224` (`.gpu` before `.ram`), doc `:181`, message `:232-234`.
  - `StatsLiteTests/MenuBarRenderSnapshotTests.swift`: boundaries `:819-822`, `:956-959`, `:1189-1202` (boundary-2 x → `gpuWidth`, plan.md correction 3); freeze order `:705-709`, `:744-751`; second inter-block pair `:516-557` → `adjacent(mem, temp)` + message `:555`; single-digit pair `:1030-1035` → `adjacent(cpu, singleDigitGPU)`, name `:1011`, doc `:101`, messages `:1043`, `:1052`; cold renames `coldMemGpu*`→`coldCpuGpu*` (17–20) and `coldCpuMem*`→`coldGpuMem*` (11–14) per plan.md correction 1; boundary labels/messages/docs `:866`, `:992`, `:1073`, `:1184-1188`, `:1244-1248`, `:1261-1262`, `:81-83`, `:94`.
- Failing test set (must be exactly this): `MenuBarBlockBuilderTests` order tests, `MenuBarAccessibilityTests` composite tests, `MenuBarTempBlockTests` order tests, `MenuBarTempVerificationTests` permutation tests, `MenuBarRenderSnapshotTests` gap/composition/freeze tests. ISC-1, ISC-2, ISC-3, ISC-4, ISC-5 all red.
- Red→green bound: `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` exits non-zero with those failures and **no other test red**; failure messages quote the new expected order (`GPU` before `MEM`).
- Stop conditions: a test outside the list fails → stop and report (do not fix blind); a listed test stays green → the expectation edit did not apply, fix the edit; compile error → fix test syntax only.
- Success checklist: suite runs, failure set matches the list exactly, zero production file in the diff (`git diff --stat` shows `StatsLiteTests/` only). `red` ✓ · `green` n/a · `v` ⏳ — receipts in the Ledger (T2).

## T3 — Green: production swap (two files only)

- [x] **T3** — `StatsLite/MenuBarBlockModel.swift`: move the `if showGPU` append (`:173-184`) above the `if showRAM` append (`:154-171`); update doc `:120-121` → `CPU, GPU, MEM, TEMP, NET`. `StatsLite/MenuBarAccessibility.swift`: move the `if showGPU` part (`:46-48`) above the `if showRAM` part (`:37-45`). Comment-only: `MenuBarStackedItemView.swift:91-92` → `CPU, GPU, RAM, TEMP, NET`; `StatusItemController.swift:311-313` → `… CPU 14 percent, GPU 28 percent, Memory Pressure …`. Verify `MenuBarAccessibility.swift:50-51` still true; do not touch it.
- Failing test: every test from T2's red set; ISC-1 through ISC-3 go green.
- Red→green bound: same suite command exits 0; 0 failures.
- Stop conditions: a T2 test stays red with the production swap in place → the band prediction (ISC-4) is wrong: run that single test with the display awake, record measured px, adjust only that constant within ±2 px (two attempts max, then escalate to the planner); any test outside T2's list goes red → scope leak, revert the offending edit.
- Success checklist: full suite green; `git diff main...HEAD` touches only the four files named in T3 plus `StatsLiteTests/`; no `.animation(` hunk (ISC-7). `red` n/a · `green` ✓ · `v` ⏳ — receipts in the Ledger (T3).

## T4 — Verification runs (planner)

- [x] **T4** — in the worktree: (a) second independent suite run under `caffeinate`, exit 0; (b) ISC-6: `MenuBarLayout.length` test green (93 pt) + composition voids ≤ 1 px; (c) ISC-5: MEM→TEMP = 21 ± 1 px green; (d) ISC-7: `rg '\.animation\(' ` over the diff returns nothing and `SparklineTimeAxisView` absent; (e) after-capture: `scripts/capture_menubar.sh` → `artifacts/2026-10-26-menu-bar-gpu-mem-swap/after/`, visual check GPU sits between CPU and MEM (spot check).
- Success checklist: two green suite runs, all ISC items verified or explicitly delegated to the reviewer; evidence pasted into the ledger below. `v` ✓ (after-capture blocked — see ledger)

## T5 — Commit + review

- [x] **T5** — conventional commit in the worktree: `feat(menubar): swap GPU and MEM status item positions`. Then reviewer code review against `git diff main...HEAD`.
- Success checklist: commit exists on `feat/2026-10-26-menu-bar-gpu-mem-swap`; reviewer verdict recorded; planner merges with `--ff-only` or `--squash` and records the merge SHA here. `commit` ✓ · `review` ✓ · `merge` ✓ `546870e` (ff, 2026-10-26)

---

## Ledger

Runner command (both runs):

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test
```

`DEVELOPER_DIR` is required on this host: `xcode-select` points at CommandLineTools. Display state checked before each run: `CGDisplayIsAsleep(0)` → 0.

- T1: red — · green — · v ⏳ · receipt commit `eeb35f0`.
  `bash scripts/capture_menubar.sh` exit 0 after a Release build (`BUILD SUCCEEDED`). The user's `/Applications/StatsLite.app` (pid 73548) was quit for the run and relaunched (pid 98361) after it.
  `before/` holds the four strips, but pixel analysis finds zero menu-bar glyphs (top 26 rows: near-white=0, near-black=0). Measured cause: `log show` records `kTCCServiceScreenCapture` denied for responsible `com.apple.sshd-keygen-wrapper` (`Platform binary prompting is 'Deny' because: is Platform Binary`); on macOS 27.0.1 `screencapture` then returns wallpaper only and still exits 0. Evidence and commands: `artifacts/2026-10-26-menu-bar-gpu-mem-swap/before/capture-note.txt`. Same treatment as plan 2026-10-25: the live spot check is environmentally void, the offscreen render tests are the gate (AGENTS.md). The T4 after-capture needs a user-side Screen Recording grant first.
- T2: red ✓ · green n/a · v ⏳ · receipt commit `cb6093f` (test-only; `git diff --stat` shows `StatsLiteTests/`, 5 files).
  Red tail:

  ```
  Test Suite 'StatsLiteTests.xctest' failed at 2026-10-26 08:38:09.978.
       Executed 446 tests, with 28 failures (0 unexpected) in 66.665 (66.804) seconds
  Test Suite 'All tests' failed at 2026-10-26 08:38:09.979.
  ** TEST FAILED **
  runner-exit=65
  ```

  28 failure records across 16 unique tests, all inside the T2 set: 7 `MenuBarAccessibilityTests` composite, 5 `MenuBarBlockBuilderTests` order (incl. `:250` `XCTAssertNil failed: "normal"`), 1 `MenuBarRenderSnapshotTests.testStackedItemCompositionFillsSlotEdgeToEdge` (4 band records), 2 `MenuBarTempBlockTests` order, 1 `MenuBarTempVerificationTests` permutation (8 records). No test outside the list failed. Messages quote the new order, for example `("[StatsLite.MenuBarBlockKind.cpu, StatsLite.MenuBarBlockKind.ram, StatsLite.MenuBarBlockKind.gpu]") is not equal to ("[StatsLite.MenuBarBlockKind.cpu, StatsLite.MenuBarBlockKind.gpu, StatsLite.MenuBarBlockKind.ram]")`. The composition bands measured 13 px (< 17 floor) and 19 px (> 14 ceiling) — the old production bands — which proves the red run ran against untouched production.
  The synthetic-adjacency gap/freeze tests (uniform, extreme, single-digit, inter-block, freeze) stay green by geometry: all three frames are 27 pt, so a pair's ink gap depends only on the right block (plan corrections 1–2). Their T2 edits did land: `rg` finds no old-order pattern in `StatsLiteTests/`, and the new test names appear in the failing set.
- T3: red n/a · green ✓ · v ⏳ · receipt commit `78d4e9e` amended to `546870e` (4 production files + 2 stale sequence-doc lines added by the planner post-review: `MenuBarBlockModel.swift:62` and `MenuBarLayoutTests.swift:153`, both `(CPU, MEM, GPU` → `(CPU, GPU, MEM`; comment-only).
  Green tail:

  ```
  Test Suite 'StatsLiteTests.xctest' passed at 2026-10-26 08:43:13.861.
       Executed 446 tests, with 0 failures (0 unexpected) in 66.745 (66.890) seconds
  Test Suite 'All tests' passed at 2026-10-26 08:43:13.862.
  ** TEST SUCCEEDED **
  runner-exit=0
  ```

  ISC-4 bands held on run 1; no constant adjusted (0 of 2 attempts used). Diff checks: no `.animation(`/`contentTransition`, no `SparklineTimeAxisView` (ISC-7); `MenuBarAccessibility.swift:50-51` untouched and still true.
- T4: v ✓ · planner independent run 2026-10-26 08:47: `caffeinate -i env DEVELOPER_DIR=… xcodebuild … test` → `Executed 446 tests, with 0 failures (0 unexpected) in 66.044 seconds` / `** TEST SUCCEEDED **` / runner-exit=0. Fourth green run 09:0x after the doc fixup: 446/0, exit 0. ISC-6 green inside that run (`MenuBarLayoutTests` 93 pt + composition voids ≤ 1 px), ISC-5 green (MEM→TEMP 21 ± 1 px), ISC-7 verified on the diff: `rg '\.animation\(|contentTransition|SparklineTimeAxisView'` over `git diff main...HEAD` → 0 matches. (e) after-capture: **blocked** — `screencapture` returns wallpaper until the user grants Screen Recording to the capture path (TCC denial recorded in `before/capture-note.txt`). Spot check only, not the gate; offscreen tests are green. Re-run `scripts/capture_menubar.sh` after the grant if the user wants the visual strip.
- T5: commit red `cb6093f` · green `546870e` (amended from `78d4e9e`) · review GO ×3 (`78d4e9e`, fixup rereview `546870e`) · merge ✓ `546870e` (ff-only, 2026-10-26; `main` = branch tip, no merge commit). Note: all three reviewer sessions recorded zero tool calls; the planner independently re-verified the load-bearing claims (full production diff, band constants unchanged, non-goal files absent, 4 green suite runs) before merging.
