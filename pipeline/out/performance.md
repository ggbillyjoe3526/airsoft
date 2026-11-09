Task: SL2 · head b2a9901 · Verdict: Pass
Run: none (cloud, no GPU; shader and diff read) · budget: no baseline yet, judged against targets and ALU/texture estimate vs site_surface.gdshader
Metrics: not measured (judgment only)
Regressions: none measured
Blocking findings: none
Advisory:
- look_vertex.gdshader fragment (judgment): wear costs 4 noise calls (about 16 hash calls, each ~6 ALU, plus 4 mixes), ~6 smoothsteps, 1 fwidth, 1 INV_VIEW_MATRIX mat-vec: roughly 150-200 ALU per pixel, zero texture fetches. site_surface does about 6 texture fetches plus its own procedural work in 429 lines, so wear is comparable and ALU-only. Fine on Ultra/High; on Low (iGPU) walls and crates covering much of the screen make it the heaviest prop pass, so the owner should check Low in Depot on real hardware.
- Uniform branch `worn > 0.0` is dynamic-uniform: wear-0 materials (tree crowns, greybox) skip the noise. But `fine` (fwidth) and the normal transform run before the branch for all pixels; move them inside the `if` (cheap fix, saves a derivative and a mat-vec on clean models).
- Streak noise at across*14 near the horizon: gated by `fine`, but the 2 streak noise calls still run when fine = 0; could skip with `if (fine > 0.0)`. Minor.
- Two new varyings (wear_at vec3, wear_foot float): 4 floats interpolated per pixel, plus MODEL_MATRIX mul in vertex for every prop vertex including MultiMesh instances. Negligible; but wear_foot is flat per instance origin so fine.
Shader variants and prewarm (judgment, read): same shader file and no render-mode or define change, so `wear` is a plain uniform and adds no pipeline variant. The new materials are extra ShaderMaterial resources only (Depot +1 racking at wear 0.35, Woodland +1 crown at wear 0), all sharing one compiled shader.
Prewarm: _material_of is called when the views are built (prop_dress.gd:230), before materials() (prop_dress.gd:94) is read for first_use (play_session.gd:885). materials() iterates every Vector2 key, so the new materials are warmed. Pass.
Draw calls / state changes: each model is one MultiMesh view with material_override; the split adds at most one material switch per map (racking, crowns vs. the rest), so draw calls are unchanged; at most 1-2 extra state changes.
Allocations: Vector2 key built per _material_of call, at build time only, not per frame. No per-frame code added. New global uniforms (look_wear, look_grime, look_dust) are set via LookConfig, not per frame.
Leaks: materials are owned by the dress dict, freed with it (RefCounted); no nodes, timers, tweens or connections added. None found.
Presets: wear scales via LookConfig.wear (one global), but there is no per-preset wear switch. Advisory: for Low, tie look_wear to 0 (the branch then skips all noise at no cost) if the owner measures a regression.
