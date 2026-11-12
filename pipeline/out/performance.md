Task: MQ1B · head cba18ac · Verdict: Pass
Run: no runtime run (box busy, no GPU; read-only review as briefed) · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and origin/main's glb
Metrics (measured from the glb JSON chunk, all meshes): file 1,350,416 -> 1,379,580 B (+2.2 %, ok, far under the 4 MiB parts cap); triangles 40,824 -> 42,274 (+1,450, +3.6 %; hands copy +1,452 by the brief's 37,824 -> 39,276 of 40,000, ok; figures' copy 2,998 of 3,000 per the brief, not re-split by me); meshes 7 -> 7, materials 6 -> 6, images 0 -> 0, skins 1 -> 1, animations 4 -> 4. Draw calls, node count, memory: unchanged by construction (same meshes, materials, bones, clips; nothing under game/).
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- assets/models/replicas/cyber.glb (judgment): the hands copy is at 98.2 % of budget, above the ~95 % aim in docs/DECISIONS.md; 724 triangles of headroom left, so the next Cyber detail should trim elsewhere.
- tests/unit/test_cyber_grip.gd:16-26 (judgment): each of the 2 tests loads/instantiates both models (4 instantiations total) and walks every Body vertex with surface_get_arrays; test-only, not shipped, freed by add_child_autofree, no leak. Could share one load via before_all if the suite time matters.
- tests/unit/test_cyber_grip.gd:41-48 (judgment): _width_near scans all vertices per call (about 4 heights x 2 edges x 4 calls); fine for a headless test.
Fixes: none required.
Unexplained: none
