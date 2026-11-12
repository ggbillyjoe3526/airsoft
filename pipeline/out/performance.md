Task: none (SD1) · head cad36f0 · Verdict: Pass
Run: none (read-only review as briefed; no Godot run, a full check is running) · budget: pipeline/perf-budget.json absent, judged against targets and the diff
Metrics: not measured (no runtime change today: no Subway block names a model, so PropDress.build returns null and the station mesh is unchanged)
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory:
- game/config/prop_dress_config.gd:365 named_only() is built once and cached (judgment): no per-call allocation. duplicate() is shallow, so the Dictionaries are shared, not copied; kind_props is rebound to a new empty one. The copy owns its own _meshes cache, so a named model is loaded twice as a Mesh lookup, but load() hits the resource cache: no second copy in memory. The copy is a RefCounted resource freed with its owner; no leak.
- game/map/map_level.gd:152 replaces _props with the named_only copy at begin(): one-off, at build time (judgment).
- game/play/station/station_surface.gd:50 adds dresses(), lay_of() and core_of() per block while building the station mesh: build-time only, O(blocks). With no kind_props and no block.dress, dresses() returns false after two dictionary lookups, so the cost is negligible today (judgment). core_of() calls dresses() again; it is cheap, but could be skipped when lay_of is TILE.
- game/play/play_session.gd:418 PropDress.build runs once per map load, not per frame. It returns null for Subway today, so no MultiMesh, nodes or prewarm entries are added. When a block first names a model, check that the prop material is covered by the shader prewarm (not testable now).
- Skipping the faces of named blocks only lowers the vertex count; colliders are unchanged (the new test asserts it).
- No _process or _physics_process code touched; no new signals, timers, tweens or per-shot code; no preset bypass.
Fixes: none required.
Unexplained: none
