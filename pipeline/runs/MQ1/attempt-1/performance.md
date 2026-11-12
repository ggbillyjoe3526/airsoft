Task: none (MQ1) · head 4ae2546 · Verdict: Pass
Run: no headless --perf bot match run (hour-long gates, no GPU; software GL) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and by reading the diff
Metrics: node/orphan/static memory not re-measured; smoke test, 5948 unit tests (incl. cache and freed-node tests) passed per the brief. Frame times: not measurable here.
Regressions (> 10 % worse): none measured
Blocking findings: none
 - replica_paint.gd:_surface_of, replica_surfaces.gd:dress (judgment): materials built once per (paint, mask, kind), bounded by MAX_WORN 160, cleared by clear(); the three Vector4 tables are static, built once, so no per-frame allocation.
 - Prewarm (judgment): one shader and no per-kind permutation (kind is a flat varying, not a define), so ShaderPrewarm via worn_materials() (play_session.gd:919) covers every surface material. Applies to clean models now too.
 - studio_sky.gd (judgment): one shared Sky, 128 px radiance, used only by the menu pictures' and turntable's own viewports, not the match. Its sky shader is not in the match prewarm; it draws in menus only.
 - Assets (measured): glbs +0.23 to +0.31 MB each (colour attribute), triangle counts unchanged; grain png 645 KB on disk, 512x512 RGBA uncompressed with mipmaps is about 1.4 MB VRAM, one shared copy.
Advisory
 - replica_surface.gdshaderinc fragment (judgment): 7 texture fetches per fragment (3 grain relief, 3 cloud, 1 mask) plus fwidth, on the one replica in the hands. That is cheap at 1080p but is the most expensive per-pixel thing on screen at 4K 240 Hz, and a large share of the screen when the gun is near. The three cloud fetches could drop to one on the Low preset, or the relief could skip when relief*fade is 0. Fetches run even where relief has faded to 0 (no dynamic branch).
 - Presets (judgment): the shader has no quality-preset hook (relief, cloud and aniso are fixed). Anisotropic filter on the grain is the platform default, so it follows project settings. Consider a Low-preset global uniform to cut the cloud and relief if the owner sees cost on low-powered hardware.
 - Bots' copies keep flat StandardMaterial3D merged by HeldMerge (held_merge.gd), so the 'many bots' draw call count is unchanged (judgment).
Owner should watch in play: F3 frame time (the 99th percentile, not the average) on the Low preset with the replica filling the view (aiming down sights, up against a wall), draw calls (the hands add no surfaces, only a changed material), and the first equip of each replica for a hitch (prewarm).
Fixes by impact: (1) fold the cloud to one fetch or a Low-preset switch if hands cost shows on GPU; (2) otherwise none.
Unexplained: none
