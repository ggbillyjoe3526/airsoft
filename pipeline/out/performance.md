Task: CN1 · head adb2321 · Verdict: Pass
Run: figure_bench headless, 11 figures, 1800 frames (no GPU; draw calls and frame times not measurable here) · budget: pipeline/perf-budget.json does not exist; no baseline yet, judged against the stated tri budgets, the owner's targets and the diff
Metrics: LOD0 tris 58,868 / 60k (ok) · LOD1 19,424 / 20k (ok) · LOD2 5,639 / 6k (ok) · glb 9,703,220 B vs 9,708,632 on main (-0.06 %) · textures body col/nrm/orm: nrm and orm slightly smaller, col re-encoded · mesh surfaces drawn per frame 236 (max), merged body meshes 6 · animation per figure mean 132.8 us, skeleton 43.9 us, both x11 1.94 ms mean / 3.8 ms p99 (script time, this machine, reported only; main not rerun, as no runtime code or mesh topology changed)
Regressions (> 10 % worse): none (LOD2 +0.3 % tris, within budget)
Blocking findings: none
 - No game/ code changed: no per-frame or per-tick allocations, node, resource or prewarm concerns (judgment).
 - Skinning: head meshes keep the same primitive count, material and skeleton; JOINTS_0/WEIGHTS_0 are already 4-wide vertex attributes, so up to 4 joints per neck vertex costs the same GPU skinning (judgment). Weights are renormalised to sum 1 in splice_heads.py.
 - Draw calls: no new surfaces, materials or meshes, so no change expected (judgment; needs a rendered run to confirm).
 - Install size: glb and textures shrank by about 7 KB in total (measured, git diff stat).
Advisory: none
Fixes: none needed
Unexplained: none
