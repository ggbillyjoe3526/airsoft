Task: SM3 · head 8a5d277 · Verdict: Pass
Run: not run (no bot-match --perf comparison; review by reading only) · budget: pipeline/perf-budget.json does not exist, no baseline yet; judged against targets and the code
Metrics: none measured. Model triangle counts from the brief are all within their budgets (gate 1471/2000, paddle 332/400, benches 858,868/1000, machine 9164/10000, office 2906/3000, counter 1458/1500, barrier 596/600) (judgment, unverified)
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory:
- game/play/station/gate_paddles.gd:130-146 refresh() per frame: 24 paddles x ~12 characters = ~290 distance tests, no allocation (typed Array[Character] iteration, scalar math); a paddle test returns early on the first near character. Judgment: negligible. Could move to the 60 Hz tick later.
- gate_paddles.gd:152-158 _place builds Basis/Transform3D (value types, no heap) and only when a paddle moves; set_instance_transform on one MultiMesh. Judgment: fine.
- gate_paddles.gd:89 _drawn is Array[Transform3D], sized once at build; no growth.
- Dead/spectated characters still count as "near" (state.characters is all); harmless to cost.
Freeing: GatePaddles is a child of PlaySession (play_session.gd:442-444), freed with it; one MultiMesh, one shared ShaderMaterial, no timers, tweens or signals. build() frees the node on the empty path (gate_paddles.gd:68). Judgment: no orphans expected.
Prewarm: material added to first_use (play_session.gd:931-932). Presets: no shadow, resolution or distance settings added; look config only (cfg.roughness, wear).
Draw calls: +1 MultiMesh (24 instances) on station maps. Gate blocks changed from fewer wide islands to 14 blocks (map data, not draw calls on its own). Judgment, not measured (no GPU).
Fixes: none required. Recommend owner records a baseline in perf-budget.json.
Unexplained: none
