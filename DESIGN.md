# Design

- Menu bar metric labels must use 8 pt regular text with the adaptive `Color.menuBarLabel` foreground style.
- The label color renders 80% white in dark appearance and 75% black in light appearance.
- This rule covers the CPU, MEM, and GPU labels and the two-row TEMP labels C and G through `.menuBarMetricLabel()`.
- Menu bar blocks are spaced by one uniform inter-block token, `MenuBarLayout.gap` = 5 pt, applied to every adjacent block pair.
- Popover metric bars (memory pressure gauge, Used memory composition bar) share `CGFloat.metricBarHeight` = 6 pt, `CGFloat.metricBarCornerRadius` = 3 pt, and the unfilled track color `Color.metricBarTrack` (the same `quaternaryLabelColor` gray as the composition bar's Free segment). Never hard-code bar geometry or track color in a card view.
