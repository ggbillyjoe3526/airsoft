Task: MB4 (attempt 1) · head cbd75ff + uncommitted tree · Verdict: Pass
Run: none (no bench; data-only change, shared cores would make frame times noise) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the MB2 measurement
Metrics: not run. Evidence: working data/maps/woodland.json is byte-identical to 85e3f52 (git show | cmp: identical), the map measured for MB2 (team_bench, Woodland 8v8, seeds 1 to 4: 4.63 ms a frame vs 4.56, +1.5 %, Pass).
Regressions (> 10 % worse): none expected (judgment; same map as the MB2 measurement)
Diff: nothing under game/. Against HEAD the JSON differs in one foliage entry (one hazel, z -38.2 to -40.5); block, bush and tree counts unchanged (checked by parsing both files). Other changes: tools/woodland/layout.py, docs, tests (test_mb4_brow.gd, test_mb4_qa.gd; test code, not exported).
Blocking findings: none
Advisory: none
Unexplained: none
Unmeasured: frame time, draw calls, node count and memory on this tree (not run; identity with an already measured map stands in). Node count, orphans and static memory depend only on map content, which is the MB2-measured file.
