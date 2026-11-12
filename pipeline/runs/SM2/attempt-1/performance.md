Task: SM2 · head 7af4936 · Verdict: Pass
Run: none (no bot-match --perf run: check.sh was running in the build thread, no second full run started; review is static) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured this run (judgment only). Draw calls / frame time: owner's hardware. Node count: +2 car Body (existing), +1 Landings MultiMeshInstance3D per level with fitting lifts, +1 Railings mesh instance (was already one).
Regressions (> 10 % worse): none measured
Blocking findings: none
Checked, all clean (judgment):
- game/map/railing_mesh.gd:42-81 build() runs once at level load (map_level.gd:327). The per-vertex appends (:138-144) go to Arrays members, so they grow in place; no per-frame path. Output is one ArrayMesh and one surface, so the railings are one draw call, as before.
- game/map/map_level.gd:331 one extra vertex_colour ShaderMaterial per level load (same shader as the props: no new pipeline or first-use hitch). It is owned by the MeshInstance3D and dies with the level.
- game/play/lift_view.gd:81-110 the load_mesh calls, _scaled (:195-209, one mesh copy), the landing placement loop and _fits are all in build(). Nothing new in _process or the tick. The per-frame leaf/button placement paths are unchanged apart from the _turn() basis (a stack Basis, no heap allocation).
- game/config/prop_dress_config.gd:465 load_mesh instantiates the scene and root.free()s it; the mesh outlives it via the Resource reference. No orphan. It is called ~8 times per level load (5 lift models + 4 railing pieces), load-time only.
- Lift materials: _model_material is shared by leaves, landings and car bodies (one material, not per instance). The leaves, landings and buttons are MultiMeshes, not split nodes. materials() returns 4 and play_session.gd:906 warms them, so no first-use hitch.
- Shader look_vertex.gdshader:97-102 the rib branch is an else-if after perforations. It costs one fract and two smoothsteps per fragment, only where UV.x < -1 (escalator steps). Other parts are unaffected. No new uniform buffer or pipeline.
- Models (tris): escalator_upper 7.4k, escalator_lower 6.7k, spiral_stair 5.9k, platform_stair 2.0k, each drawn once as a SET; lift_car 5.6k x2; landing 728 x6 via MultiMesh. About 30k tris extra at most on Subway, well within a Low preset's reach for a single map. Static geometry, with no per-frame cost beyond the vertex load. The shadow pass is the only multiplier, and it goes through the quality presets as before.
Advisory:
- game/play/lift_view.gd:81 PropDressConfig.load_mesh is called per model, including the same file for each level load (judgment); a cache would save load time only. Not needed.
- Escalator/spiral meshes at 6-7k tris each are fine for Ultra. On Low, the owner should confirm Subway stays at 60 FPS on his low-end rig (frame times can't be measured here); if it dips, a lower-detail escalator is the first thing to trim.
Fixes: none required.
Unexplained: none (no measured metrics to explain)
