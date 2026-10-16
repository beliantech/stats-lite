# Tasks: 2026-10-15-stats-lite-view-weight

Plan: .pi/plans/2026-10-15-stats-lite-view-weight.md (in this worktree)
Branch: feat/2026-10-15-stats-lite-view-weight
Worktree: /Users/jonathan/beliantech/stats-lite/worktrees/2026-10-15-stats-lite-view-weight
Rule: one coder per task, one commit per task (fast-forward merge per phase).

## Task 1 — Phase 1: Popover lifecycle (lazy mount, nil on close)
Objective: zero view evaluation while the popover is closed.
Files: StatsLite/StatusItemController.swift, StatsLiteTests/ (new test if feasible).
Spec: plan Deliverables Phase 1. Do NOT set contentViewController in init. Mount NSHostingController(rootView: PopoverContentView(...)) lazily in togglePopover(_:). Set contentViewController = nil in popoverDidClose(_:). Keep the 0.25s re-entrancy guard, button highlight behavior, and NSPopoverDelegate wiring intact. Document in code comment that @State coresExpanded resets on close (accepted).
Verification hooks: xcodebuild test passes (all existing suites); AC-1 partial — no crash on rapid open/close (unit test driving togglePopover twice).
Commit: fix(popover): lazy-mount hosting controller and release it on close

## Task 2 — Phase 2: Snapshot equality excludes timestamp
Objective: unchanged-metric ticks do not invalidate views.
Files: StatsLite/MetricTypes.swift, StatsLiteTests/MetricTypesTests.swift.
Spec: plan Deliverables Phase 2 + AC-7. Custom == comparing enabled, cpu, memory, memoryPressure, gpu; exclude timestamp. Add AC-7 tests: equal metrics with different timestamps compare equal; each single-field change produces inequality.
Verification hooks: new AC-7 tests green; full test suite green.
Commit: fix(monitor): exclude timestamp from SystemSnapshot equality

## Task 3 — Phase 3: Zero-allocation HistoryBuffer + Equatable SparklineView
Objective: no per-tick heap allocation from history; sparkline re-evaluates only on real change.
Files: StatsLite/HistoryBuffer.swift, StatsLiteTests/HistoryBufferTests.swift, StatsLite/SparklineView.swift, the three card views.
Spec: plan Deliverables Phase 3 lockstep algorithm verbatim (prefix-while expired count, removeFirst on BOTH points and values, overflow removal, .map forbidden inside append). Keep public API shape so existing call sites compile; update cards to use stored values. SparklineView: Equatable (values + tint); apply .equatable() at card call sites. AC-8 tests: values matches points.map after fill, multi-point age eviction, capacity truncation; allocation test (measure allocations per steady-state append, expect 0 after warm).
Verification hooks: AC-8 tests green; full suite green.
Commit: perf(history): stored values array in lockstep with points, Equatable sparkline

## Task 4 — Phase 4: Sparkline fixed-step right-anchored geometry
Objective: full width from first sample, empty start, no warm-up stretch; capacity from preferences.
Files: StatsLite/SystemMonitor.swift (sparklineCapacity), StatsLite/SparklineView.swift, StatsLiteTests/ (new SparklineViewTests), the three card views (pass capacity).
Spec: plan Deliverables Phase 4 + Appendix A Part 2 component skeleton VERBATIM (except capacity comes from monitor.sparklineCapacity, not a hardcoded 30). Geometry: dx = plotWidth / max(capacity-1,1); x_i = (width - inset) - (N-1-i)*dx; N=0 empty; N=1 dot at (width - inset, y0); N>=2 stroke + area fill per skeleton; clamp y to [inset, height - inset]; domainMax epsilon 0.0001; .frame(height: 38); .accessibilityHidden(true). Cards pass capacity: monitor.sparklineCapacity. AC-9 unit tests as listed in plan. AC-10: test sparklineCapacity for all historyDuration (30, 60) x refreshInterval (1, 2, 5) combos.
Verification hooks: AC-9 + AC-10 tests green; full suite green; build Release clean.
Commit: feat(sparkline): fixed-step right-anchored geometry, preference-derived capacity

## Task 5 — Phase 5: Menu bar redraw-churn fix (revision 2)
Objective: eliminate ~205 CGDrawingLayer.draw/s; AC-11/AC-12.
Files: StatsLite/MenuBarStackedItemView.swift (remove .contentTransition(.numericText()) and .animation(.easeInOut(duration:0.2), value: block.valueText)), StatsLite/StatusItemController.swift (PassthroughHostingView sizingOptions = []; frame-based layout: translatesAutoresizingMask = true, autoresizingMask [.width,.height], frame = button.bounds), AGENTS.md (rule: no .animation/.contentTransition on status item path), tests (assert no contentTransition/animation modifiers on the status item view; keep existing 146 green).
Verification hooks: xcodebuild suite green; Release build; re-measure AC-11 (breakpoint/trace zero draws) and AC-12 (CPU <0.1%, footprint <50MB) after merge.
Commit: fix(menubar): remove digit-roll animation, pin hosting view sizing

## Final (planner-run, after Task 5): AC-1/AC-6/AC-11/AC-12 re-measurement
Redraw-count, 5-min idle CPU, 15-min footprint protocol, plus spot VAC re-check (static visuals must stay byte-identical — only the transition animation is gone). Recorded in the plan's verification ledger.

