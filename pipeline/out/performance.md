Task: FT1 · head d946192 · Verdict: Pass
Run: no measured run (re-check of the diff 766afe7..d946192; cloud container has no GPU, no frame times or draw calls) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured. Unchanged by the diff (judgment): treeline.glb is rebuilt with the same 192 triangles; no node, material, mesh or surface is added; the skyline keeps its one look material and its glow surface; the vertex colour array already was a PackedColorArray, so its size is the same.
Regressions (> 10 % worse): none measured
Blocking findings: none
- Shader (look_vertex.gdshader:22-26, 122-124): one uniform bool and one branch mixing ALBEDO by COLOR.a. It is a uniform branch, coherent across the draw, and only the skyline sets it true (skyline_view.gd:61). Cost is a mix per fragment on the skyline, negligible (judgment). No new material, so no new prewarm entry; the shader variant is the existing one.
- Allocations: the `out` alpha write in skyline_models.gd:151-153 and skyline_view.gd:266-268 is in the build path, run once per map build, not per frame or per tick (judgment). `keep` is a plain float on Placed and Part.
- Wear (prop_dress_config.gd:347): spruce wear 0 skips the props' wear branch for that model, a small saving at most. It adds one dictionary entry, read at build time.
- Preset bypass: none. The palette entry (look_config.gd:143) and the treeline colour and keep values are data only.
Advisory: none
Unexplained: none
