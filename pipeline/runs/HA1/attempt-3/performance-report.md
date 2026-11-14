Task: HA1 · head ef9d94f (delta ec22685..ef9d94f) · Verdict: Pass
Run: no match (Godot not started, per the brief). The glTF JSON was measured with Python and the code read. Budget: pipeline/perf-budget.json has no baseline yet, so judged against the owner's arms limits (docs/CC0_ASSETS.md) and attempt 2's figures.
Metrics (arms.glb, measured):
- File size 6.48 MB (limit 8, ok); attempt 2: 6.48 MB (unchanged).
- Materials 4 (Sleeve, Glove, GloveArmour, Skin; limit 4, ok). Images 9, all 2K, about 3.3 MB (palm map repainted; sizes within 2 % of attempt 2).
- Triangles drawn gloved 38,900 (Arm 2x2,976 + GloveKit 2x2,824 + HandSurface 2x13,650); skin only 34,452 (Arm + Skin 2x13,650 + Nails 2x600). Both under 40,000 (ok). Identical to attempt 2; no mesh object added.
- Clips 28 (same). Key data 598 KB (input + output accessors; attempt 2: about 613 KB, so -2 %).
- Draw calls and frame times: not measurable here.
Regressions (> 10 % worse): none.
Blocking findings: none.
Advisory:
- No file under game/ changed (judgment, git diff --stat), so no per-frame or per-tick allocation, node, timer, connection or preset change and no new shader or material to prewarm.
- tests/unit/test_ha1_rifle_hold.gd (judgment): the new test does CPU ray casts; test only, not shipped.
- tools/blender/arms/* are build tools, not shipped.
- Skinning cost of about 39k triangles with the sight raised is still unmeasured; check on the owner's hardware under Low.
Fixes: none required.
Unexplained: none.
