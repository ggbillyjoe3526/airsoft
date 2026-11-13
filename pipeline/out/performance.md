Task: MB2 · head 99930c3 · Verdict: Pass
Run: team_bench (a whole PlaySession on Woodland, 8v8, seed 1, 30 s = 1800 frames, headless, 2 runs each side) · budget: no baseline yet (pipeline/perf-budget.json is absent), judged against targets and a41c1e9
Scope: data only (data/maps/woodland.json, tools/woodland/layout.py, tests, docs); no game/ code, no new material, particle or shader.
Blocks: a41c1e9 has 945, head 946 (MB1's merged map had 945; MB2 adds the one thicket). Log stack 2.8 m -> 1.8 m changes no count.
Metrics (mean / p95 ms, base runs then head runs; script time per tick, same machine):
- tick: base 4.60/6.34, 4.62/6.27 · head 4.52/5.51, 4.55/6.28 (ok, no regression)
- frame (views): base 1.55/2.36, 1.55/2.35 · head 1.53/2.25, 1.54/2.31 (ok)
- both: base 6.15/8.41, 6.17/8.09 · head 6.05/7.34, 6.08/8.27 (ok; well under Low's 16.7 ms CPU frame)
- frames over 16.7 ms: base 14, 8 · head 6, 8 (all from the one-off worst-case first-frame spike of 70-90 ms on both sides)
- Level build time, node/instance counts, draw calls: not reported by this tool headless (no GPU); the one added block is 0.1 % of 945.
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- judgment: the thicket's spruce MultiMesh adds instances in one block, not new nodes or materials (shared spruce dress), so draw calls should not move; confirm on the owner's GPU with F3 near (21.5, 42).
- measured: the 70-90 ms worst tick occurs on both base and head (not caused by this change); worth a separate look.
Unexplained: none
Tree: data/maps/woodland.json was swapped for the base map for two runs and restored with git checkout; working tree clean apart from this report.
