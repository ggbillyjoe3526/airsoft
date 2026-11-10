Task: FT1 · head c84e494 · Verdict: Pass
Run: no measured run (the game has no `--perf` match flag here; the cloud container has no GPU, so no draw calls or frame times) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured. Instance counts are unchanged (judgment, from the diff: grid_spread changes positions and sizes only, `n` is untouched).
Regressions (> 10 % worse): none measured
Blocking findings: none
 - No per-frame or per-tick code changed (judgment). Every edit runs at map or skyline build time: PropLayout._grid (prop_layout.gd), SkylineView/SkylineModels/SkylineShapes (one extra float `haze` per placed part, one multiply per vertex while building), MapLevel.CORE_SHARE constant.
 - Skyline specular (look_vertex.gdshader): one uniform and `SPECULAR = specular;` in fragment(). The shader already ran the PBR path, so this is a constant write, no extra texture or branch. Zero cost (judgment). Material is set once at build (skyline_view.gd), shared, no new per-instance material.
 - No new materials, particles or meshes, so no new prewarm entry is needed. No presets bypassed (specular and treeline_fade live in SkylineConfig, not a quality setting).
Concern: spruce overdraw in thickets (judgment)
 - Wider spruces (grid_spread 1.8 x 1.5, clamped to the box) overlap neighbours more, so more fragments are shaded then depth-rejected. Forward+ has no depth prepass by default, so overlap in screen space costs fragment work only on the Low target's pixel-bound cases.
 - Mitigations in the diff: vertex count is the same (~2,600 x 474 tris), the draws are the same, and the core boxes are lower (0.2 of height instead of 0.6) and inset further, so fewer greybox faces are drawn behind the spruces. Net overdraw is bounded by spruce size, which the box clamp caps; I expect a small fragment cost increase, not a frame-time risk. The shader is a simple vertex-colour one, so fragment cost per layer is low.
 - Thickets are mostly seen at range, where the spruce covers few pixels. Close up the overlap is highest; that is where a modest GPU would show it.
Advisory
 - Frame time on Low is unverified: on the owner's hardware, look into a thicket close up on Low (F3 overlay, draw calls and FPS) against origin/main once. If it is flat, nothing to do.
 - No perf-budget.json lines yet; the owner records a baseline.
Fixes: none needed.
Unexplained: none
