Task: SM1 (delta 41037a8..f16abfc) · head f16abfc · Verdict: Pass
Run: no runs (delta is a diff read; the full check runs separately; no GPU in the container) · budget: no baseline yet, judged against targets and the 41037a8 pass
Metrics: not re-measured. Static: +2 small MultiMeshes (cab LEDs 256 tris x3, end LEDs 172 x1 = about 940 tris), strips 6 -> 12 instances; draw calls +2 (judgment, not rendered)
Regressions (> 10 % worse): none measured
Blocking findings: none
 - train_view.gd:_process (judgment): runs only with flickering strips (3 on Subway, set_process off otherwise in _ready). Per strip it makes floats/ints only (flicker_level, roof_view.gd:101, has no array/string/Callable); Color is a value type; set_instance_custom_data only when the level changes. No per-frame allocation.
 - Built once: _link_flickers loops strips x lamps at build only, not per frame.
 - Freed/resources: two new ShaderMaterials (_lamps, _leds) are held by the TrainView and freed with it; no nodes, timers or connections added. LED/strip MultiMeshes are shared, per model.
 - Prewarm: materials() now returns 3 (body, lamps, LEDs); both glow materials use the same LENS_SHADER, so one shader variant, covered.
 - Presets: glow meshes have shadows off; nothing bypasses the quality presets.
 - RoofLamps.recolour (roof_lamps.gd): one light_color set per in-train lamp at build.
Advisory:
 - roof_lamps / station lamps in trains now BAKE_DYNAMIC for the 3 flickering lamps: dynamic spot lights cost shadow-map renders on the Low preset (judgment, owner's hardware to confirm); they are only 3, and a flickering lamp has to be dynamic.
 - 12 strip instances all share one glow ShaderMaterial; the flicker is per instance custom data, so no per-instance materials (good).
 - Triangles are inside docs/records/SM1.md Budgets (LEDs 256 of 270, 172 of 180).
Fixes: none needed.
Unexplained: none
