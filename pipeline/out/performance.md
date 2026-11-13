Task: MB2 (attempt 2) · head 1fb3fd0 · Verdict: Pass (after the longer rerun; the 30 s Fail was noise plus one seed)
Run: team_bench, Woodland 8v8, headless, no GPU · (a) 30 s, seed 1, 4 runs a side interleaved (mine) · (b) 120 s = 7200 frames, seeds 1-4, one run at a time on an idle machine, order alternated (coordinator; raw /tmp/bench_ab.out checked, figures match) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main
Scope: data and dev tools only (woodland.json 960 blocks vs 945, generator, tests, map_heat.gd); no game/ change, no new material, shader, particle or sound.
Metrics (mean ms, script time on one machine):
(a) 30 s, seed 1: tick base 3.91 -> head 4.67 (+19 %), frame 1.30 -> 1.52 (+17 %), both 5.21 -> 6.19 (+19 %); base runs spread 4.85-5.73, so noise about +-10 %; worst tick base 67-73, head 43-52.
(b) 120 s, seeds 1-4:
- tick: base 3.38, 3.51, 3.52, 3.20 (3.40) · head 3.86, 3.18, 3.29, 3.44 (3.44, +1 %)
- frame (views): base 1.24, 1.27, 1.14, 0.99 (1.16) · head 1.31, 1.13, 1.16, 1.14 (1.19, +2 %)
- both: base 4.62, 4.78, 4.66, 4.19 (4.56) · head 5.17, 4.31, 4.45, 4.58 (4.63, +1.5 %); p95 base 6.4-7.0, head 6.7-7.3
- frames over 16.7 ms of 7200: base 10, 6, 7, 3 · head 17, 7, 5, 7 (totals 26 vs 36, the spread is one seed)
- worst tick: base 115, 21, 26, 26 · head 49, 34, 51, 67 (first-frame and load spikes; head's 67 on seed 4 is not seen in base, advisory)
- Level build time, node and draw-call counts: not reported headless; blocks +1.6 %.
Regressions (> 10 % worse): none across seeds 1-4 on the pooled mean (+1 to +2 %). Seed 1 alone is +12 % both at 120 s (+19 % at 30 s), seeds 2-3 are cheaper on head: a different fight on one seed, not a map cost. Absolute head 4.6 ms is far under Low's 16.7 ms CPU frame.
Blocking findings: none
Advisory:
- judgment: seed 1 is dearer on head both times; if it shows in play, profile nav queries and bot thinking around the bent road (tools/map_heat.gd for route load) before the collision shapes.
- measured: head's worst ticks (34-67 ms on seeds 2-4) exceed base's (21-26 ms) there; one-off spikes, not in the 95th/99th percentile; worth a look at the first-frame load if hitches are felt.
- judgment: confirm draw calls on the owner's GPU with F3 near the Long road (shared spruce dress, should not move).
Unexplained: seed 1's +12 % at 120 s (probably the bots' route there); the worst-tick spikes above.
Tree: woodland.json restored; git status clean apart from this report.
