Task: UG1 · Lamp light: roof lamps and night pools as real shadowed lights (no task block; judged on the brief)
Attempt: 1 of 4
Head: a79f8ea (= HEAD; brief says tools/check.sh still running, so this verdict holds only if it goes green; QA and
performance reports taken from the brief, pipeline/out holds older tasks' files)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 6/8 → Retry (two non-blocking judgment fails)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
7. [judgment] tools/lamp_pictures.gd:1-66 is a second "render a map from fixed spots at a preset" tool beside
   tools/eye_pictures.gd, which already takes preset=ultra. Meanwhile tools/eye_pictures.gd:108 still calls
   apply_field without the lamps, so it renders Ultra Depot with no lamp light and the sun at full strength, which is
   not how a match draws it. It also makes the map cards and pictures. Fix: pass roof.lamp_lights() there and drop
   lamp_pictures.gd (or fold its PlaySession spots into eye_pictures).
7. [judgment] game/save/graphics_apply.gd:254 names LAMP_ATLAS_DEFAULT, which doesn't exist (it's LAMP_ATLAS_SIZE).
   game/config/lighting_config.gd:90 has a broken comment wrap ("it moves to another" on a line of its own).
   game/play/roof_view.gd:6 still says "none of it casting a shadow, so the overhead sun ... lights the hall" as its
   lead clause.
8. [judgment] game/play/README.md has no row for the new game/play/roof_lamps.gd. Its rows 42 (light_pools: real
   lights by "the Mesh detail row's count", no shadows) and 45 (roof_view: "none casting a shadow") are now wrong.
   DECISIONS.md:1065 ("Real light counts are fixed: Low none, Medium 2, High 4") doesn't mention that Ultra's Far now
   gives 8.
Must-fix for the next attempt: eye_pictures.gd:108 passes the lamps, and lamp_pictures.gd is removed or merged; fix
the three comments; update game/play/README.md (new row, rows 42 and 45) and the DECISIONS real-light line.
Advisory: the renders compare Medium with Ultra, so GI, AO, fog and reflections change as well as the lamps. One pair
of Ultra shots with Lamp light Off and Far would back the "about as bright" claim. glass_atlas's "/ 2"
(graphics_apply.gd:266) could be a named constant. lamp_lights uses BAKE_STATIC, so toggling it mid-match with GI
Scene leaves SDFGI's lamp bounce stale until the cascades rebuild.
Owner should test in the game (at most 6, one line each):
- Depot on High and Ultra, at 6v6 looking down the hall: the frame time (F3) against Ultra's 4.2 ms aim (DECISIONS:1054).
- Depot, Custom with Lamp light Off and then Far, all else Ultra: the hall's brightness stays about the same.
- The Lounge and the Offices on Ultra: no lamp light comes through their roofs, in the main view and through a scope.
- Switch Lamp light mid-match with GI on Scene: no leftover bounce light or glow.
- Woodland at night on Ultra: the fires' shadows look right and don't flicker as the real lights move between pools.
- High at night with a torch: the torch's shadow softness looks as it did before.
