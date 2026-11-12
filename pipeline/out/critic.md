Task: SM5 · Subway's lamps and extras
Attempt: 1 of 4
Head: 550d11c (HEAD matches; the brief has gdlint, notes, wiki, test_station_fixtures 8/8, test_sm5_qa 6/6 green; the full unit run and smoke test were still running, so this verdict stands only if tools/check.sh finishes green)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (each marked measured or judgment):
1. [judgment] Models, sm5-1-lamps.jpg against 31-ceiling-lamp/121814 (the caged batten the record says it follows): no render matches the photo's side elevation. From the nearest views: length:height 11.7 (1.52/0.13) against 9.1 (+29 %); body:guard height about 3:1 against 1:1 (the photo's wire cage is half the fitting's depth, the render's guard is a thin row of stubs under a white strip, so it reads as a plain office batten, not a caged one); guard bays 6 against 9 (-33 %); side clips 2 a side against 4 (-50 %); top brackets 0.12 of the length from the ends against 0.24 (-50 %), and they are flat pads, not the photo's hook hangers.
1. [judgment] tunnel_lamp against 32-tunnel-lamp/122005 and 121940: the outline is a pointed octagon (visible faceting on the flange and dome) where both photos are a stadium (parallel straight sides, round ends); width:height 0.65 against 0.55 (+18 %); end lugs about 10 % of the height against 5 % (2x) and plain blocks. Construction fails: station_lamps.py:100 builds each cage bar as "a ridge of two faces", so in the side and quarter views the bars are flat ribbons ending in spikes that stop in mid-air short of the flange and poke past the vertical bar (sm5-1 side panel). A real cage is round bar joined to the rim at both ends.
1. [judgment] fire_extinguisher against 33-extras/fire_extinguisher: body height:diameter about 4.8 against 3.5 to 3.75 (+28 to 37 %, too slender); the horn is a flat black wedge, not a round cone on a hose. cctv_camera: hexagonal housing faceting reads at close range; the bracket is a thin rod and a floating cube where photos 3 and 4 have a stout arm and ball joint.
1. [judgment] sm5-4-in-game.jpg is the only in-game evidence and it still shows "Kingsmere" (panel 2). Copperhill is checked only in the studio render (sm5-3), so the shipped board has not been seen in game.
Notes (not failures): sm5-2 clock panels "side" and "front" are labelled the wrong way round. Code, contracts, allocations, teardown, tests and the team-hue gates are sound. StationFixtures builds once, and test_station_fixtures:194 samples the sheet against reads_as_team.
Must-fix for the next attempt:
- strip_lamp: rebuild to photo 121814's proportions (length:depth near 9, a body and a wire cage of equal depth with 9 bays of round wire, 4 clips a side, hook hangers inset a quarter of the length), and add a side-elevation render next to the photo.
- tunnel_lamp: make the flange and dome a stadium with enough segments that no facets show; give the cage bars round sections joined to the flange at both ends; make the lugs half their current size and screw-lug shaped. Spend the budget on curves, not ridges.
- fire_extinguisher: widen the body to about 1:3.6 and make the horn a round cone on a hose. cctv: round the housing and give it a stout arm with a joint.
- Re-shoot sm5-4 with Copperhill on the boards and correct panel labels.
Owner should test in the game:
- Look up at a strip lamp from a platform: does it read as a caged industrial fitting or a plain tube?
- Walk a running tunnel near a bulkhead lamp: cage, outline and glow at 2 m.
- Name boards on both platforms read "Copperhill" (left to right, not mirrored, from both sides).
- Does the crimson extinguisher read as an extinguisher or as pink?
- Strip lamps in the west passage and z-running rooms run along the room (the turn).
- Way-out sign: "Way out" faces those heading to the street, "Platforms" those heading down.
