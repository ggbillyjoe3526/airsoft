Task: SM5B · head 640241d · Verdict: Pass
Run: not run (headless --perf match skipped: the diff changes only data, models and build-time code; no GPU here) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and by reading the diff
Metrics: nodes +9 MultiMeshInstance3D (about 33 fixture MultiMeshes in all) (judgment); draw calls +9 on Subway at most, if all are in view (judgment, unmeasured); static memory +about 9 small meshes (34 to 84 tris, glb about 4.8 KB each) (judgment); assets/ is 122 MB of the 500 MB install budget (measured); signs.png source 4.5 -> 5.0 MB (+0.49 MB), the sheet is still 2048 x 2048 BC7 so VRAM does not change (judgment). Frame times: not measured, owner's hardware only.
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory:
- data/maps/subway.json: about 60 placements go into the existing per-model MultiMeshes (28 posters at 0.6 are instances, not nodes). Added instances cost only vertex work, a few thousand triangles at most.
- game/config/station_fixtures_config.gd:13-15: nine new MultiMeshes, each a separate draw call. On Low that is small, but a room-by-room view-distance check on the owner's laptop is worthwhile. Merging the wall plates into one mesh with a shared material would cut it to 1 to 2 draws (judgment).
- game/play/station/station_fixtures.gd:63: the scale is applied in placings(), at build time only. There is no per-frame allocation. A non-uniform Basis is fine for the MultiMesh, and uniform 0.6 keeps normals correct enough (judgment).
- game/map/station_dressing.gd:212-215: parsing happens once at load. A bad scale returns null (the fixture is dropped), with no leak.
- New fixtures share the signs.png material, so there is no new material or shader and no prewarm gap (judgment). Fixtures follow the existing MultiMesh teardown path, and no new timers, tweens or connections were added.
Fixes: none required. If draws matter on Low, merge the wall plates (see advisory 2).
Unexplained: none. The headless --perf comparison against origin/main was not run, so node, orphan and memory deltas are inferred from the diff, not measured.
