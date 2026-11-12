Task: TB1 · QA commit (see git log, "QA: TB1 vault ... report") · Verdict: Pass

Blocking: none.
Advisory:
- Removing the old lintels (vault_air) opens the 0.15 m wall at z -9.075 / 9.075 between track and platform above the car roofs (y 3.3 to 4.4); intended, and no solid changes below y 3.6 anywhere in the vault footprint (80k seeded samples, old vs new subway.json). BBs can now pass over a car roof to the track; confirm in play.
- test_freeing_a_station_level_leaves_no_orphans passes but GUT prints "70 Orphans" for test_station_dress.gd; same test body as on main, not attributed to TB1.

Tests added:
- tests/unit/test_tb1_vault_qa.gd:test_no_gap_behind_the_arc_along_the_whole_tunnel · collider 2 cm behind the arc at 19 angles, every 3.7 m along both tunnels (existing test checks one x) · without vaults the vault count assert (2) fails on main's map.
- tests/unit/test_tb1_vault_qa.gd:test_the_air_under_the_crown_is_open · no collider in mid-air under the crown (walkable air unchanged) · same vault-count assert fails on main.

Ran (all pass): test_station_dress (25), test_climb_qa, test_pp1_climb_qa, test_bot_climbs, test_mt1_qa, test_mt2_qa, test_subway_rename: 75 tests, 21,893 asserts, 0 failing; new file 2/2. Subway loads without MapData warnings. Climb ledges, bot climbs and malformed-dress handling (words, vaults warned and left out) covered by those. Raw output: pipeline/out/qa/run1.txt. tools/check.sh not run by me (running elsewhere); smoke test not run.
Not tested: window modes, real display look of the arc, words orientation as drawn (test only pins the font and placement), focus/mouse (untouched by change).
