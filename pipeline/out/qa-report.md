Task: WR2 · QA commit 847b86d (my test file was swept into the worker's commit; head moved from ae6c160 through d646e35 to 847b86d, I tested that tree) · Verdict: Pass

Blocking: none.

Advisory (nothing to fix before merge):
1. tests/support/match_runner.gd:231 · sized_for(map, base) ignores a `base` whose round_time the caller set: on Woodland it is replaced by 180. No Woodland caller sets one today (MatchGuard.overtime_flag, match_guard.gd:131, runs on Depot only), but an overtime guard added for Woodland would silently play 3:00 rounds, not its short ones.
2. game/map/map_catalog.gd:145 · a Round cell of 20 digits passes is_valid_int, and to_int() then logs an engine ERROR (overflow) before the warning; it still falls back and lists the map. _read_sizes (line 118) has the same, older, pattern. Trigger: put 99999999999999999999 in the Round column.
3. UX note, as the record intends: on Woodland, Skirmish shows 3:00 and switching to Custom shows 2:30 (its own default switch).
4. The A/D guard (16 seeds, Normal, night) passed: 125 rounds, 108 flag raises, 0 run out the clock, no bot held up past the limit. Raises in 86% of rounds is a balance figure, reported not asserted.

Checked and clean: all 8 leaves stand on their ground (leaf corners within 3 cm; outside the wall the ground falls away at most 0.9 m, no overlap); every leaf hangs on its hut's outer face; a rebuild of build_map.py is byte-identical to woodland.json and check.py gives TOTAL 0; both poles stand on the terrain with no block over them and clear of the Box and Shed roofs; Depot, the Range, practice and no map keep the tuning's time, Custom plays its own; the HUD clock, round clock and Match card chips read 3:00 on a Woodland Skirmish and 2:30 on Depot. The round cell accepts 90 to 300 in 30 s steps and refuses 89, 301, 0, -180, 100, 185, 180.5, 3:00, 1e2, 180s and nan; a missing Round column and a short row still list the map.

Shared physics space: I checked every file that builds a Woodland MapLevel and also plays a match or session (test_bushes, test_baked_light, test_dd1_qa, test_wl9_qa, test_ki1_qa, test_night_light_qa, test_practice_spots). Each frees its level before the match or uses a session without its own level, so none is exposed, and all pass. test_woodland_layout is the only one at risk; it opens its doors during its match and restores them. The worker added this to KNOWN_ISSUES.

Tests added (tests/unit/test_wr2_qa.gd, 10 tests, 2003 asserts, 43 s, all pass):
- :71 a bot walks in and out of every hut doorway and opens each shut leaf · without the doors the shut-leaf opened assert fails; the walk only passes because the doorways are open.
- :89 a body in the doorway stops the door shutting; once clear it shuts · fails if the leaf sat in the gap or `blocked` ignored the body.
- :110 each door starts as the map says · fails on a wrong shut flag.
- :117 poles on the ground, in no block · fails on a floating or buried pole.
- :129 round time on a Woodland Skirmish only; Depot, Range, no map and Custom keep theirs; the chips show 3:00 · fails without the Round column.
- :148 practice keeps the tuning's time.
- :158, :170 Round cell edges; no column and short row.
- :191 PlaySession clock and score bar: 3:00 Woodland, 2:30 Depot, Custom's 2:00 on Woodland · fails if the round time isn't played.
- :206 a Woodland Attack / Defend session has two flags and runs 180 frames clean.

Other runs (all pass): woodland_layout 17 (87 s), do1_qa, doors, two_flags 18, team_sizes 17, match_page 28, wl2_qa, cr2_qa, flag, bushes, baked_light, dd1_qa, wl9_qa, ki1_qa, night_light_qa, practice_spots, dp2/3/4_qa, bb_walls, terrain, bot_vaults, sf2_qa, wl1_qa, props, mm3_qa, night_sight(_qa), site_dress, fg2b_qa, fm1_field_map, woods_view(_qa), hud_minimap, plus the Woodland A/D guard (1207 s). Raw output: pipeline/out/qa/.

Not run: tools/check.sh, the full suite and the smoke test (told not to); Woodland's Elimination guard and the Easy and Hard A/D guards; how the doors look, sound and swing in play, which needs a display and ears.
