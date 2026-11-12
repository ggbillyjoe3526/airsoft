Task: TB2 · Subway's running tunnels arched like the trains
Attempt: 1 of 4
Head: 41e8db5 (checks passed on it)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 6/8 → Retry (near miss, judgment: check 1 alone stands between it and Accept)
QA Pass, performance Pass; no blocking findings of theirs to file.
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] The owner asked for tunnels that "closely match the shape of the trains". This change matches SM1's
   unmerged car, which isn't in this repo, so nothing here can be checked against it. In the build this PR ships, the
   train is the greybox box. tools/subway/layout.py:207-217 springs the arch at T+2.7 = -16.2 at z 9 and 12.6. But
   train_s (layout.py:159, x 30-60, z 9-12.5) has a roof shell at P+2.4..2.7 (-15.6..-15.3). Over x 50-60 the car's side
   walls and roof corners stand up to 0.9 m above the springing, through the drawn lining. Its roof edge at z 9.3 sits
   0.26 m above the arc. QA's "15 cm slabs at x 59.85" are that shell (data/maps/subway.json:10497). The tests excuse
   it outright (tests/unit/test_tb1_vault_qa.gd:41, :94, :109 skip anything styled `train`). So the arch cuts the
   train instead of hugging it.
   [judgment] The arch doesn't read in play. In tb2-08 and raw 18 the lining is black, and the only shape you see is
   ribs floating in the dark, ending in mid-air at the springing. The record admits it ("reads mostly by its rings",
   docs/records/TB2.md Known issues). A released game wouldn't ship the owner's headline ask unreadable.
7. [judgment] tests/unit/test_station_dress.gd:574 `1 if d == null or true else 0` is a tautology: the assert
   always expects 1 and hides the intent. game/config/station_look.gd:52 rewrites the rib comment ("grey concrete
   ... dark rings") but leaves the colour pale grey (0xc8cbcc), so the comment no longer matches the colour.
Passed, briefly: 2 no Contracts touched (dressing read keeps drop-and-warn, station_dressing.gd:334). 3 all new code
   runs at map build (station_surface.gd:82-86, :142-145, _add_mouth :158), nothing per frame. 4 test_station_dress.gd:561
   {"mouth":"east"} would be kept on main, and the vault-count asserts (4 vs 2) fail without the change. 5 rules stay in
   tools/ and the map data; nodes only draw; types complete. 6 cosy, toy-like Tube look, no tone issue. 8 Dev-content map,
   PLAYTEST lines added, the changelog note comes next.
Must-fix for the next attempt:
- Make the arch and the car in this build agree. Shape the south train's shell over x 50-60 to the arc (chamfer or
  round its roof corners in layout/build_map, as SM1's car will be). If the owner prefers, wait for SM1 instead.
  Either way, drop the `train` exemptions from the vault tests so a car's shell through the arc fails them.
- Make the arch visible: a lining tint or roughness that catches the tunnel lamps, or lamps that wash the curve.
  It should read as a curved ceiling with no ribs drawn, and the rib ends shouldn't float. Show a render.
- Fix the tautological assert (expect 1 warning per dropped vault, plainly) and the stale rib comment.
Owner should test in the game (at most 6, one line each):
- From the south track at x 60 and from the platform tunnel looking east: does the box car's roof run into the arch?
- Walk both running tunnels on High and Low: can you see a curved ceiling, or only floating rings?
- The north mouth at x 50: the corner fans and the 10 cm step (z -12.5 vs -12.6) where the two tunnels meet.
- Shoot up into the arch near the springing and over the car: each BB stops where it hits.
- Bots through run_n, run_s and the cross passage; the detrainment steps at the south cab, under the arch.
- F3 on Low along a running tunnel: 60 FPS (blocks 879 → 1026).
