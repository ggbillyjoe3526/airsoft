<<<<<<< HEAD
Task: none (MB1) · head 85bcc67 · Verdict: Pass
Run: headless level+nav build per map, 2 runs each, origin/main vs head (git archive copies, data/maps untouched; the working-tree woodland.json differs from HEAD's, so HEAD's was measured) · budget: no baseline yet (perf-budget.json absent), judged against origin/main
Metrics main -> head (measured, headless; draw calls/frame times need a GPU, not measured):
- Woodland: blocks 949->945, level nodes 1890->1842, colliders 1842->1794, nav nodes 529,108 (same), level+nav build 4.87 s->4.68 s, nav alone 4.1->4.3 s (noise), static 708.5->704.6 MB, orphans 0
- Depot: blocks 220->222, nodes 583->585, nav 194,400 (same), build 1.08->1.23 s (+0.15, 2 runs), static 287.0->286.7 MB, orphans 0
- Subway: blocks 951, nodes 985, nav 85,115, all same; build 1.24->1.19 s
- find_route, 200 seeded random pairs, mean (max): Woodland 2.98->3.94 ms (57->66), Depot 1.83->2.04 (11->12), Subway 2.77->2.94 (19->14)
- Disk: depot.res 131,173->131,665 B (+0.4 %); depot.json +385 B; woodland.json 572,789->573,893 B (+0.2 %); subway.json -903 B
Regressions (> 10 % worse): find_route mean Woodland +32 % (~1 ms), Depot +11 % (noise: second run +3 %); no monitor in the --perf list moved. Cause not pinned: nav grid size is identical; likely the extra solid pieces and thickets change the obstacle layout the search runs round (judgment). Same order as the known 6.1 ms Woodland average in KNOWN_ISSUES (can wait; one search a tick).
Draw calls / primitives (judgment, no GPU): Woodland's block count falls by 4 (trees -> thickets/cordwood/root plates swap), so block meshes do not rise. The 19 new bushes (foliage 99->118) join the existing MultiMeshes by bush_chunk grid cell (bush_view.gd:34-58); at most a few new chunk draws if one lands in an empty cell. Fort plywood wall, crates, spruce thickets reuse existing dress kinds (no new material, mesh or shader, so no prewarm entry). Woodland stays over the 150-draw ceiling; this change moves it by 0 to a few draws, not measurable here. Owner's card: F3 draw calls at Woodland High.
Lane points: Woodland 10/9/12 -> 15/18/16, Depot 18/14/21 -> 18/15/21, Subway 23/14/21 -> 12/14/15. Lanes are read when RoundPlanner picks routes (per round/errand), not per frame; 3-18 points, negligible (judgment).
Install: export_presets.cfg exclude_filter covers tools/*, tests/*, docs/*, pipeline/*; the new map_heat/map_survey/plan.py/los.py never ship (+ .uid files under tools/ too). Map data grows ~0.5 KB total.
Teardown: map_heat.gd:76 and map_survey.gd:97 call runner.free_level() before quit; orphans 0 in my runs of the same path.
Blocking findings: none
Advisory: Woodland find_route mean +~1 ms (above); re-check on owner's hardware at the next perf pass; Woodland's 150-draw overage stays an owner/playtest item.
Unexplained: the Woodland route-time rise (not in the diff as code; layout-driven, not attributed).
=======
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
>>>>>>> origin/main
