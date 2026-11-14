Task: HA1 · head db5afd5 · Verdict: Pass
Run: static only (no Godot run, per brief; glTF JSON of both files read) · budget: docs/CC0_ASSETS.md Size limits; perf-budget.json has no lines (no baseline yet), judged against those limits and attempt 4 (9f3de58)
Metrics (now / attempt 4 / limit):
- arms.glb size 6,477,004 B (6.18 MB) / 6,476,164 B / 8 MB (ok, +840 B)
- Materials 4 / 4 / 4 (ok); images 9 / 9 (2K limit unchanged, no image touched)
- Triangles, gloved look (Arm 2976 + GloveKit 2824 + HandSurface 13650, x2 sides): 38,900 / 38,900 / 40,000 (ok, 97 %)
- Triangles, bare look (Arm 2976 + Skin 13650 + Nails 600, x2): 34,452 / 34,452 / 40,000 (ok)
- Per-mesh triangle counts identical to attempt 4 (10 meshes, 67,400 total, only 2 looks drawn at once)
- Clips 28 / 28; animation keys 31,887 / 31,887 (re-bake changed values, not counts)
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
- tests/unit/test_ha1_qa4.gd, test_ha1_qa5.gd, test_ha1_qa3.gd: CPU vertex and bone loops, test only, not shipped (judgment).
- tools/blender/arms/{pose,hold_solve,hold_tables,sight}.py: build tools, not shipped (judgment).
- No file under game/ changed, so no new per-frame or per-tick allocation, node, resource, prewarm or preset path (measured by diff stat).
Unexplained: none
