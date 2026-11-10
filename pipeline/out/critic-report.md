Task: MT1 · Kingsmere, the metro station, as a Dev-only greybox map (no task block; judged against the owner's v2 brief)
Attempt: 1 of 4
Head: a3c6352d (check.sh passed on 82002d94; since then only QA's tests, the roof.plain fix 77779ede and the reports)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Flag A's letter sits in the train's roof. game/play/flag_view.gd:261 puts the "A" at
   (pole_height 3.4 + letter_rise 0.5) x scale (2.1/3.4 = 0.618) = 2.41 m over the foot, and the label (font 96 x
   0.006 = 0.58 m, centred, not scaled with Standing) spans about 2.1 to 2.7 m. Flag A stands inside the south car
   (tools/kingsmere/layout.py FLAGS, foot y 0.9) whose ceiling is 2.4 m over it (the wall block above at y 3.3 in
   data/maps/kingsmere.json), so the top half of the objective letter is buried in the roof. DECISIONS says the poles
   were shortened to fit the car; the letter was missed, and QA's test only checks it is lowered, not that it clears.
Passes, briefly: 1 otherwise met: spiral stair 0 to -10 only, one ordinary stair -10 to -18 with a half landing,
tunnels 0.5 m over the cars, CQB above (28/23 m) and 58 m only on the platforms (field_standard.gd:84 exception,
reasoned from the brief), Street team in the ticket hall, Tunnel team in the cross-passage, lifts shut and deferred
to MT2 (stated default), dev tag (data/maps.md:33). 2: contracts untouched; MapData/FlagView/RoofLamps gain optional,
additive fields. 3: no _process/_physics_process/handler changes; set_flicker (roof_lamps.gd:96) allocates nothing;
the new work is build-time (17 ms plain_reaches once). 4: test_mt1_qa.gd test_kingsmere_loads_without_problems fails
without the map file; test_field_rules runs Kingsmere through every field check. 5: floor_under is pure MapData; new
values are RoofConfig exports and the map's poleHeight. 6: greybox, no branding, works-site dressing, not militaristic.
Advisory (non-blocking): tests/README.md:10 and tests/support/dev_content.gd:4 still say every shipped map is public;
area_probes.gd:349 `probe_eye * 2.0` is a bare factor; map_data.gd is now 861 lines.
Must-fix for the next attempt: keep a flag's letter under the ceiling over it: either cap the letter's height at the
map's poleHeight plus a small clearance from config (e.g. a FlagViewConfig letter_clear) or scale the letter with
Standing and place it so its top clears 2.4 m in car A; add a test that Kingsmere's letter A top stays under the
ceiling above flag A (MapData.floor_under/ceiling from the blocks). Fix the two stale "every map is public" lines.
Owner should test in the game (at most 6, one line each):
- Attack / Defend: is the "A" in the south car fully visible and readable, and B on the stair landing?
- Fall into the south track pit: does walking up to 40 m to the end steps feel like a fair trap or a chore?
- Do the Tunnel team's pushes through the south car and the stair feel fair (attackers won 67.7 % in 8 seeds)?
- Does the 58 m platform line dominate the lower level, or just open it up as the brief wanted?
- Medium preset: is the flat, lamp-less shading underground playable (KNOWN_ISSUES row)?
- Ultra/High on your hardware: frame time with 106 shadowed strip lamps.
