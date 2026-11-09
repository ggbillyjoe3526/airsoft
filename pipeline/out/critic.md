Task: SL1 · Sunlit Concrete: the light, grade and paint
Attempt: 1 of 4
Head: b2ae737 (checks passed on it)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✗ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 5/8 → Retry (judgment)
Gate: no SL1 performance report on disk. pipeline/out/performance.md is the torch task's (0765d76) and performance-report.md is FL1's, so the "Pass + advisory" can't be checked; write it before the next critic run.
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
4. [judgment] The step's one new mechanism, look_paint, has no test. Delete it from all four shaders (look_vertex.gdshader:49, look_clear.gdshader:15, site_surface.gdshader:425, door_leaf.gdshader:23) and every test still passes. Only the global's declaration is pinned (test_look.gd:37). The new tests (test_look.gd:307-335) cover grass, night and flag cloth, not the paint grade.
7. [judgment] Comments now contradict the code: look_light.gdshaderinc:1-6 still says "BOTW's soft light … soft cel bands with a gentle mid step … cool violet (never black)"; map_style.gd:151 still names "the palette's meadow" for GRASS (now `grass`); site_look.gd:140 still calls the surfaces "the look's clean surfaces" at grit 0.6.
8. [judgment] The record lists three open issues (docs/records/SL1.md › Known issues left: Depot's violet and crimson roof until SL3, no model wear until SL2, the grit cost on Low), but docs/KNOWN_ISSUES.md has no rows for them. PROCESS.md:189 requires a row for each.
Passed, briefly: 1 matches the brief and the record: day light (lighting_config.gd:22-40), shade, bands, rim and paint (look_config.gd:28-43, project.godot:274-305), grade (look_config.gd:47-52), grit (site_look.gd:126-145), every look shader muted, Depot and Range rebaked. 2: no Contracts entry is touched. 3: no CPU work per frame; look_paint costs one dot and one mix per fragment, and the grit cost is perf's advisory. 5: values are data in the Resources, with typed exports. 6: the renders match the owner's brief, muted and natural, and team cloth is kept out of look_paint (test_look.gd:332).
Must-fix for the next attempt:
- Write the SL1 performance report to pipeline/out/performance.md.
- In test_the_shared_materials_draw_in_the_shared_light, assert that each look shader's ALBEDO goes through look_paint( and that the include defines look_paint reading look_paint_saturation.
- Rewrite the three stale comments (look_light.gdshaderinc:1-6, map_style.gd:151, site_look.gd:140).
- Add KNOWN_ISSUES rows for the roof (until SL3), model wear (SL2) and grit on Low (performance, playtest).
Owner should test in the game:
- Depot's back racks and the gap behind the green container go near-black: can you still spot a bot there?
- Team blue and orange on figures still read as the loudest colours against the muted maps.
- Woodland's foliage and grass read as natural green, not khaki or pastel mint.
- The Street's meadow floors and pastel terraces at 60 % paint.
- A night map still looks right; the day retune must not leak into it.
- Low preset frame rate on Depot with grit 0.6.
