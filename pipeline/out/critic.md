Task: WA1 · Woodland in the art direction (no TASKS.md block; judged against the brief, the owner's 2026-10-31 ruling, docs/ART.md › A map in the look and docs/records/WA1.md)
Attempt: 1 of 4
Head: 7310ead (= git rev-parse HEAD; record: gdlint clean, check.py TOTAL 0, targeted GUT pass, full suite left to CI)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Retry: no QA or performance report for WA1 (pipeline/out/qa-report.md is WR3's, performance.md WR3's). On the checks alone this is an Accept (one non-blocking fail); it stands once both reports say Pass.
Evidence for the passes:
1. Shared light: map_level.gd:496-497, woods_view.gd:251 and 302-303, bush_view.gd:33, look_clear.gdshader (new). Palette: look_config.gd:112-118, map_style.gd:45-118, woods_config.gd:16/43/86-92/109/138-140/182, minimap_config.gd:73, build_map.py:455, build_props.py:55-75. Grid gone: map_style.gd:115-116, map_level.gd:494-497. Rebakes: depot.res, range.res, test_dp2_qa.gd:13-14.
2. No contract touched; LookMaterials.vertex_colour only gains a defaulted `srgb` (look_materials.gd:14-15).
3. All new materials are made at build time (MapLevel build, WoodsView/BushView build, _make_puddles). Nothing new per frame.
4. test_look.gd:92-117 fails on main (crown, bush, terrain and timber colours aren't in the palette); test_look.gd:120-138 fails on main (the greybox and woods are StandardMaterial3D).
5. All changes are presentation. Types are on everything. Colours are config data. There is no global state.
6. The palette is vibrant and kept off the team hues (test_woods_view.gd:223, test_look). It's toy-like, not grimdark.
7. Small, focused edits. Notes, not fails: the sRGB-to-linear line is copied in look_vertex.gdshader:17 and look_clear.gdshader:13 (one helper in the include would do). It also runs per fragment over the whole greybox and ground, where StandardMaterial3D did it per vertex; doing it in vertex() would cost less.
Failed checks, with evidence:
8. [judgment] The docs this change affects are stale:
   - docs/ART.md:88-109: the palette table (which the doc calls "the look's palette") lacks all 15 Woodland entries (bark through mud_wet).
   - docs/ART.md:62: says "every tree a dark-green cone", but the crowns are now canopy, green, pine and fern.
   - docs/ART.md:202-203: still says "(Woodland's CC0 recipes join when it moves onto the look)"; WA1 added them.
   - docs/ART.md:80: credits the hue test to test_look.gd; for the woods colours it is test_woods_view.gd:223.
   - game/map/README.md:15: still describes MapLevel's mesh "with a metre grid".
Must-fix for the next attempt: get QA's and performance's WA1 reports (both Pass). Fix the five doc lines above in the same push.
Owner should test in the game (at most 6, one line each):
- Woodland by day on Low and on Ultra: do the crowns, bushes and meadow read bright and clean, with no white glow or flat patches? (ART step 4 asks for both presets; the record only pictured High.)
- Woodland at night: is the greybox, woods and bushes' shared-light shade still readable under the moon, with fireflies over the puddles?
- The crimson and yellow leaf drifts (woods_config.gd:109): do they read as autumn leaves, not as markers or team paint?
- 145 teal crates: does teal dominate the Truck bend and crate areas? (ART: "big repeated props take a neutral".)
- The Range: its greybox now has new colours, no grid and the shared light. Is distance still easy to judge without the metre lines?
- Depot after the rebake: is the hall's bounce light unchanged to the eye?
