Task: SM4 · head adefc97 · Verdict: Pass
Run: seed 1234, smoke match (Depot, headless; 795 frames head / 895 main) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main
Metrics: nodes_max 2199 / 2199 (ok), orphans_max 1031 / 1031 (ok, same on main, load-time), draw calls 0 (headless, no GPU: not measurable), frame times not measured (owner's hardware).
Install size: 19 new .glb = 1.6 MB of assets (assets/ 119 MB total) vs 500 MB budget (docs/DECISIONS.md): ok (measured).
Regressions (> 10 % worse): none
Blocking findings: none
 - Code: runtime changes are load-time only: map_data.gd:385-392 reads `facing` once per block; prop_layout.gd `_fit_facing`/`_faced_size` run at map build, not per frame/tick. No new per-frame allocations, nodes, timers or connections (judgment).
 - Models are drawn through the existing PropDress MultiMesh path with vertex colours and the shared look material; colliders unchanged, so physics and BB cost is unchanged (judgment).
Advisory:
 - The smoke match plays Depot, not Subway, so Subway's own node count and draw calls are unmeasured (measured gap). Expect about 19 more MultiMesh draw calls (one per model, more with shadows) and at most ~37 instances; the owner should read the F3 overlay on Subway at Low and Ultra.
 - game/config/prop_dress_config.gd:130-150: 19 models, 750-2,940 tris each, within model-list budgets; if the Low preset's draw distance or shadow settings are honoured by PropDress as for existing props, no preset bypass (judgment, not exercised).
 - No new shader or particle, so no prewarm entry needed (judgment).
Fixes: none required.
Unexplained: main ran 895 frames vs 795 on head in the same smoke match (timing-dependent end condition); node and orphan counts are identical, so not attributed.
