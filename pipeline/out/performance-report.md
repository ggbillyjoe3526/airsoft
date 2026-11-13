Task: HA1 · head 8218b4d · Verdict: Pass (delta since b960370; first-run findings kept)
Run: no new match (checks still running on the shared cores; the delta adds no nodes, timers or connections, read from the diff). Earlier --smoke --perf on b960370 vs main: nodes_max 2231 / 2227, orphans 1051 / 1051. Budget: pipeline/perf-budget.json absent, no baseline yet; judged against targets and origin/main
Metrics (arms.glb, head / origin/main, measured from the glTF JSON): file 5.98 MB / 2.42 MB (limit 8 MB, ok) · 28 / 26 clips, animation key data 377 KB / 340 KB (+37 KB) · materials 4 / 5 (limit 4, ok) · 9 / 1 embedded images, all 2K webp (ok) · mesh index sum 40,100 / 39,420 over all 8 meshes; drawn is 38,900 gloved, 34,500 skin only (README), within 40,000 (ok). Draw calls and frame times: not measurable here.
Shotgun clips: they are in origin/main's arms.glb already (shotgun_Hold/Fire/Reload), so they cost nothing against main. HA1's own clip change is +2 clips, pistol_two_* and cyber_two_* (+37 KB keys, about 1.5 % of the file). The file growth is the HA1 skin textures, not clips.
Regressions (> 10 % worse): file size 2.42 → 5.98 MB (+147 %) and triangles 39,420 → 40,100 index sum (+1.7 %); both are HA1's intended model and inside the owner's arms budget, so reported, not blocking. Nodes and orphans: none.
Blocking findings: none
Advisory:
- game/play/arms_tuck.gd:42-48 (clear): no heap allocation. _bones is a PackedInt32Array built once in _init (:31); get_bone_rest returns a Transform3D value, basis.get_scale a Vector3 (judgment, read). Cost: 3 bones x (get_bone_rest + 2 sets), about 9 cheap native calls per frame while the sight is raised; negligible next to the seek and force_update_all_bone_transforms it precedes (judgment).
- game/play/arms_view.gd (_draw_in): the shotgun's aim_tuck / aim_slide entries run the same per-frame path as the rifles; one more weapon on it, no new allocation, bounded to ADS frames (judgment). Skeleton re-evaluation per frame on ~39 k skinned triangles stays unmeasured; check on the owner's hardware under Low. If it hitches, limit the seek to frames where the raise changed.
- game/play/replica_view.gd ~287: hands_busy joined the carry target; a bool in an existing easing, no allocation (judgment).
- Kept from the first run: arms_fade.gdshader is covered by ShaderPrewarm via ArmsView.materials(); fading materials are built once and cached; the aim_hint lookups are Dictionary reads without allocation; hands_motion.gd:step is allocation-free.
- Material count fell to 4 (HandSurface shares the skin material), so fewer state changes than main.
Fixes: none required.
Unexplained: none (orphans_max 1051 is identical on origin/main, so not from this diff).
