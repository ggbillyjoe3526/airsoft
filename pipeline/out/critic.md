Task: TB1 · Subway's platforms like the Tube
Attempt: 1 of 4
Head: c992ec3 (checks passed on 5ece2f4; later commits are QA tests, reports and the record, no game code)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (near miss, judgment: fixing check 1 alone gives Accept)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Construction: /mnt/project-files/concepts/metro/pt1/v2/2-north-platform.jpg (AFTER, about px 1140-1230 x 245-270)
   shows a black wedge above the standing car's west end, where the tiled parapet (the 0.15 m wall at z -9.075, cut to
   the car roof by vault_air, tools/subway/build_map.py +370) meets the vault. Either a hole into the void or an unlit
   or wrong-finish face over the opened car-roof air (vault_boxes side walls, build_map.py +405-410). It is visible in
   the owner's own first-person shot from the platform end.
1. [judgment, pixel means measured] The owner asked for the trackside wall to be "white and almost match the rest of the
   station". In 1-south-platform-across.jpg AFTER, the platform back wall averages RGB 110,108,104, the trackside wall
   88,83,77 and the vault 76,70,62 (warm taupe, R-B +14; BEFORE's cream trackside was 79,67,51). The vault and the far
   wall still read brown-grey, not white. The record notes the warm cast as a known issue instead of fixing it
   (station_look.gd +50 vault_tile tint alone doesn't fix it).
8. [judgment] The record (docs/records/TB1.md, Decisions › Posters) says the owner's "larger posters" belong to SM5's
   thread, but SM5 and posters appear nowhere in docs/, game/ or git history: the ask isn't tracked. No KNOWN_ISSUES row
   for the vault's warm cast. The new game/play/station/platform_words.gd has no folder README row (game/play/README.md).
Advisory: MIND THE GAP orientation reads correctly from each platform (platform_words.gd +62-76, run = -up). The
   words are 0.24 m tall on a 0.45 m coping with a 0.1 m yellow line; the Tube's line is much bolder, so check it reads.
   The springing has a hard 19° crease where the vertical wall meets the arc (visible in render 4).
Must-fix for the next attempt: find and close the black wedge over the north car's west end (and check every car end
   on both tunnels from the platform and the track). Make the vault and the trackside wall read white under the
   station's light (tint, probe or lamp fill), close to the back wall's value; re-render the four shots and compare.
   Track the posters ask in docs/TASKS.md (or build them) and correct the record. Add the KNOWN_ISSUES row and the
   README row.
Owner should test in the game (at most 6, one line each):
- Stand at the north platform's west end and look east: no black gap above the car next to the platform.
- Are the vault and the wall across the track as white as the platform's back wall, on High and on Medium?
- Shoot up into the vault from the platform and the track: BBs stop on the curve, never short in the air or inside it.
- Throw a smoke over a standing car: it lands on the roof or falls back, never sticks; BBs over a car roof feel fair.
- Read MIND THE GAP from both platforms, standing and crouched: legible, and the right way up.
- F3 on Low, looking along a platform: 60 FPS.
