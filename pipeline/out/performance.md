Task: ST1 · The Street · head 915afe2 · Verdict: Pass
Run: no seed or frames (no bot match; the owner has the match guards running separately); headless build probe of street, depot and woodland (MapLevel + WoodsView, built then freed) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the other maps built the same way on this machine
Metrics (street / depot / woodland): level build 51 / 107 / 761 ms (ok); level nodes 543 / 262 / 1004 (ok); level mesh vertices 17.4k / 7.9k / 15.2k (ok); woods nodes 3 / 0 / 30 (900 trees are one MultiMesh, ok); nodes after free 1 on all three; orphans 0 (ok); static memory 80.3 / 79.7 / 85.1 MB (ok); draw calls and frame times not measured (no GPU)
Regressions (> 10 % worse): none (no per-frame or per-tick code changed; origin/main has no Street to compare)
Blocking findings: none. The earlier one (Glass material missing from the shader prewarm) is fixed in 915afe2: MapLevel.glass_materials() (map_level.gd:164, empty without glass) is appended to first_use at play_session.gd:723 before _woods.materials(); _level is built at line 317, before _build_views; tests/unit/test_street.gd asserts the list holds the Glass material (judgment, read; one extra MeshInstance3D reference, no per-frame code, no leak).
Advisory
- game/map/map_level.gd:85-97 (measured): the glass is 3 blocks of 525, one surface, no shadows; cost is negligible. One transparent pass over a night/day field is fine; no preset bypass found.
- data/maps/street.json (measured): 17 light pools, under LightPools.MAX_POOLS 32; real lights are capped per preset and cast no shadow (light_pools.gd:7, 190). 900 forest trees are one MultiMesh scaled by WoodsConfig.forest_share per preset (Low none); under most_forest_trees 6000.
- 509 area boxes and 525 blocks: build cost 51 ms, one-off. tests/support/field_measure.gd:_nearest_linked scans all nav nodes once (cached) and only in tests; not a runtime cost.
- game/map/map_data.gd:337: colour parse is load-time only; no allocation concern.
Fixes, ranked by impact: none needed.
Unexplained: none. Not measured: draw calls, frame times and a rendered first-sight check (owner's PC); no match-level --perf run (guards own the machine; no per-frame code changed).
