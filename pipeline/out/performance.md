Task: SM5 · head 122ea50 · Verdict: Pass
Run: no --perf match run (a full tools/check.sh was running; no GPU) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and by reading the diff
Metrics: not measured this run (node count, orphans, draw calls, frame time all unmeasured); judgment from the diff only
Regressions (> 10 % worse): none measured
Blocking findings: none
 - Allocations: StationFixtures builds once (play_session dress part 2); no _process/_physics_process, no signals, no timers/tweens (station_fixtures.gd) (judgment)
 - Teardown: views are children of the session and freed with it; MultiMesh/ArrayMesh/3 materials are refcounted and held only by the nodes and _materials (judgment)
 - Presets: shadows off and GI disabled on every view (station_fixtures.gd _add); no light, no particles, glass is unshaded (judgment)
 - Shader warm-up: materials() (prop, glow, printed) is appended to first_use (play_session.gd); printed shares look_vertex, the glow shader is new and covered (judgment)
 - look_vertex.gdshader: use_sheet is a uniform bool, a coherent branch, one extra unset sampler bind on every material; negligible (judgment)
 - signs.png: compress/mode=2 (VRAM, BC7), 2048x1024 about 2.7 MB VRAM with mips, anisotropic filter; fine (judgment)
Advisory:
 - station_fixtures.gd:_add: each MultiMesh spans the whole station, so no per-instance culling; 12 models, up to 3 surfaces each, so at most about 36 draws are always submitted while Subway is visible. Rendered run needed to confirm; visibility_range_end or merging small models would cut it.
 - station_fixtures.gd:build: sheet load is synchronous on the build path; fine if it stays before the warm-up.
 - Owner: please record a Godot baseline in perf-budget.json; one rendered Subway run (draw calls, F3) would settle the draw-call point.
Fixes: none required
Unexplained: none
