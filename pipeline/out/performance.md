Task: BL9 · head 4de834a · Verdict: Pass
Run: judged by reading git diff 0f115be 4de834a (no new smoke run; the earlier --perf run on 0f115be matched origin/main: nodes_max 1339 / 1339, orphans_max 879 / 879) · budget: no baseline yet, judged against targets and origin/main
Metrics: smoke.glb 152,544 B, 5,292 tris; flash.glb 78,488 B, 3,460 tris / 200 KB and 5,500 tris per file (ok). Draw calls and frame times not measurable here.
Regressions (> 10 % worse): none
Blocking findings: none
Advisory (judgment):
- grenade_view.gd:98-100: _lie_reach is filled once in setup from each mesh's get_aabb(); one PackedFloat32Array of 3 floats, freed with the view. No per-frame cost.
- grenade_view.gd:285-289: _draw_canister calls _lying() (static; Basis and Transform3D are value types) and reads _lie_reach[kind]: no heap allocation per frame. Mesh still assigned only when the kind changes.
- _bodies removed: one fewer held material reference; the paint materials stay alive through their meshes and prewarm via materials(). No leak, prewarm unchanged.
- grenades.py: flash flash ring now 12-sided: flash.glb 3,460 tris (was 2,812), 78 KB, both under budget; negligible.
- Surface count per bomb (7 smoke, 6 flash; about 91 extra draws worst case) is unchanged from the earlier review: do a rendered check on Low.
Fixes: none required.
Unexplained: none.
