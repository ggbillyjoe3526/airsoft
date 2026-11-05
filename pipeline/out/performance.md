Task: BL9 · head 0f115be · Verdict: Pass
Run: smoke match with --perf (fixed smoke seed), headless (no GPU), head vs origin/main worktree · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main
Metrics: nodes_max 1339 / 1339 main (ok), orphans_max 879 / 879 main (ok, same as main), draw calls 0 (headless, not measurable). Assets: smoke.glb 152,544 B, flash.glb 82,184 B / 200 KB per file (ok); 5,292 and 2,812 tris / 5,500 per file (ok). Frame times not measured.
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- assets/models/grenades/*.glb (judgment): 7 surfaces (smoke) and 6 (flash) per bomb vs 1 before = 6 to 7x draw calls per bomb. Worst case 12 bombs + 1 held = about 91 extra opaque draws (only while bombs are live; most matches far fewer). Shadows off, so no shadow-pass multiplier; fine on Ultra, worth a rendered check on Low. Merging surfaces that share a material (or fewer than ~4 materials) would cut it.
- game/play/grenade_view.gd:197-213 (judgment): the model loads once in setup per GrenadeView (PropDressConfig.load_mesh frees its instanced scene root; duplicate() is one mesh per kind, shared by all slots). No per-bomb mesh or material; meshes are RefCounted and freed with the view. No leak.
- grenade_view.gd:264-279 and 331-350 (judgment): per-frame path allocates nothing new (Basis/Transform3D are value types; mesh assigned only when the kind changes). No signals, timers or tweens added.
- grenade_view.gd:182-189 (judgment): materials() now returns every surface material of both kinds, de-duplicated with Array.has, for ShaderPrewarm; it runs once, so no hot-path cost. Prewarm covers all model materials: no first-use hitch.
- load cost (judgment): two glb loads at setup (about 235 KB total), once per match; negligible.
Fixes: none required.
Unexplained: none (frames 4047 vs 4469 is the smoke match ending at a different point, not a per-tick cost; script time not compared).
