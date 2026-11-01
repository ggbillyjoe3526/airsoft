Task: ST1 · QA commit 9895544 · Verdict: Pass

Blocking: none.

Advisory (for KNOWN_ISSUES, none caused by a bug in the change):
- game/config/map_style.gd:140: the kind "glass" has no entry in `surfaces`, so a BB that hits the House's windows or the bus shelter's pane takes the CONCRETE default (tick, puff, sound). KNOWN_ISSUES covers bots seeing through glass, not this. A one-line surface (METAL or a new GLASS) would fix it; a production change, not mine.
- game/map/map_data.gd:337: a fractional colour (1.5) is accepted and truncated; only out-of-range or non-numbers are problems. Harmless.
- Worktree carries an uncommitted docs/DECISIONS.md edit that is not mine; tests/unit/test_wa1_qa.gd.uid (WA1's missing uid) rides in a976606, harmless.
- Rebuilding tools/street/build_map.py into a scratch copy gives data/maps/street.json byte for byte.

Tests added (tests/unit/test_st1_qa.gd, 9 tests, 95 asserts, 7.5 s); each checked by mutating a scratch copy of the tree (not the repo):
- :54 colour 0 is a colour (alpha 1) and 0xffffff reads · colour guard changed to > 0.0 -> fails
- :64 -1, 16777216, a string, true, [1], null are problems and leave the colour unset · same mutation -> fails
- :76 own colour wins over a gravel surface's, else the surface's · block_colour's own-colour branch removed -> fails
- :86 FieldChecks.drawn_colours counts a painted block as "crate #7658aa", an unpainted one as "crate" · branch disabled -> fails
- :93 Glass mesh: absent on a glassless map, present with it; greybox vertex count unchanged by the pane; vertices at 0.35 alpha; a BB still stops on the pane · is_clear skip removed from the greybox -> fails
- :118 The Street has one Glass mesh and 3 clear panes
- :129 flag_head_start: 1.3 for street (below the standard 1.6), the standard and no reason for depot, woodland, unknown ids · exception set to 1.6 -> fails
- :139 the Street's flag passes at "at least 1.3", and under another id fails "need a head start ... 1.6" · exception removed -> fails
- :151 the middle is a node end 0's first spawn links to, every spawn has a walk to it · fallback disabled -> fails

Ran, all passing: test_street 5, test_st1_qa 9, test_look 16, test_map_level 15, test_field_layout 15 (2 m 7 s; measures the Street, none of its checks newly fails), test_field_rules 18, test_levels 19, test_team_sizes 17, test_assets 5, test_balance_report 10, test_skyline 12, test_baked_light 12, test_doors 20, test_fm1_field_map 15, test_map_areas 11, test_minimap_field 11, test_night_light 16, test_nav_grid 21, test_fb1_menus 21, test_title_and_menus 13, test_bb_walls 1, test_night_sight_qa 5, test_flag 10. No script errors. Raw output: pipeline/out/qa/st1_*.txt.
CI matrix filters checked by reading: elimination_at_normal, attack_defend_at_normal and at_night each match the intended guard tests only.

Not run (as told): tools/check.sh, the match guards (test_street_guards), the smoke test; they are running separately and decide the suite totals.
Owner's list (needs a display): glass at 0.35 opacity in day and night light and from both sides; palette read of the terraces against teams; the Glass mesh's z-order against the sky.
