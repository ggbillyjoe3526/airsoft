Task: HA1 · head 9f3de58 · Verdict: Pass
Run: no Godot run (QA holds it); arms.glb measured statically from its glTF JSON · budget: docs/CC0_ASSETS.md > Size limits (no perf-budget.json lines), compared with attempt 3 (ef9d94f)
Metrics (measured, now / attempt 3 / limit):
- File size 6.48 MB / 6.48 MB / 8 MB (ok)
- Materials 4 / 4 / 4 (ok)
- Images 9 / 9 / 2K (unchanged; git shows only arms.glb changed under assets/models/arms)
- Triangles drawn, gloved: 38,900 / 38,900 / 40,000 (ok; Arm 2x2976 + GloveKit 2x2824 + HandSurface 2x13650)
- Triangles drawn, bare: 34,452 / 34,452 / 40,000 (ok; Arm + Skin 2x13650 + Nails 2x600)
- Mesh objects 10, index counts identical to attempt 3
- Clips 28 / 28; sampler key data 31,887 keys (small, no growth in file size)
Regressions (> 10 % worse): none
Blocking findings: none
Advisory: none
- Diff since ef9d94f touches no runtime code of HA1: the only file under assets/ is the rebuilt arms.glb (re-baked left-hand finger poses); tools/blender/arms/*.py are build tools (not shipped); test_ha1_rifle_hold.gd is test only (CPU vertex loops, run only in GUT, not in game).
- game/ changes in the range (ui/hud*, weapon_rail, replica_pictures) come from the merged origin/main work (PB3, AU11), reviewed by their own threads; not reviewed here.
- No new material, particle or shader, so no prewarm entry is needed; no preset bypass.
Fixes: none needed
Unexplained: none. Frame time, draw calls, orphan nodes and static memory were not measured (no Godot run allowed); nothing in the delta can move them, since mesh, material and image data are unchanged.
