Task: WG3 · head 1606137 (+ uncommitted docs) · Verdict: Pass
Run: headless script (no GPU), Woodland, map's dressing seed; PropLayout.layout once, PropDress.build x3 · budget: no baseline yet (pipeline/perf-budget.json absent), judged against the owner's targets, the earlier pass on this branch and the model budgets in tests/unit/test_wg3_woodland_models.gd:8
Since the earlier pass: no shipped code changed (last game/ commit f2633c8); only watch_tower.glb (394,892 -> 397,328 B) and footbridge.glb (143,480 -> 146,812 B) changed. The new gap test is tests only.
Metrics (measured):
- Triangles: watch_tower 5,942 / 6,000 ok · footbridge 2,896 / 3,000 ok · sawmill_shed 4,688 / 5,000 ok · hut_roof 1,368 / 1,500 ok · hut_roof_long 1,476 / 1,500 ok · palisade 56 a stake + 20 a rail, about 970 a 4 m section / 1,000 ok. Every model 1 surface (1 material).
- Placed: palisade 2,942, palisade_rail 216, tower/bridge/shed 1 each, roofs 2 + 2; 6,857 props in all.
- PropLayout.layout 15.1 ms; PropDress.build 21.7-23.0 ms (127 MultiMesh views, 646,462 drawn triangles over all Woodland props). One-off at match build (play_session.gd:410, staged dress part 0), not per frame.
- Orphan nodes 1 -> 1 over three build-and-free cycles (no leak).
Regressions (> 10 % worse): none. Tower and bridge add 86 triangles each, +172 in a 646k-triangle prop set (+0.03 %), one instance each, no new draw call, material or shader.
Blocking findings: none.
- No new per-frame or per-tick code: STAKES and SET run only inside PropLayout.layout at build (judgment).
- No new node or resource kinds: the new models go through the shared mesh cache (prop_dress_config.gd mesh_of) and the shared vertex-colour material, chunked MultiMesh as before (judgment).
Advisory:
- game/play/site/prop_layout.gd:111 a PackedFloat32Array per palisade block and prop_layout.gd:139 an array literal per block: build-time, small, fine (judgment).
- game/config/prop_dress_config.gd:250 set_box scans every block; called once per SET model (prop_layout.gd:58-63, guarded by sets_laid), so 3 scans of Woodland's blocks at build (judgment).
- The tower sits 58 triangles under its 6,000 budget and the bridge 104 under 3,000: any further detail needs triangles taken elsewhere first (measured).
- Shadows: the palisade's 165k stake triangles in 20 chunks still cast on Medium and up (earlier pass); frame cost there needs the owner's hardware (judgment).
Fixes: none needed.
Unexplained: none. Frame times and draw calls not measured (no GPU); owner to check F3 on Woodland, Medium and Low, near the palisade and tower.
