Task: FM2 (none; owner playtest 2026-11-01) · QA commit the one that adds this file (on top of 3929b2c) · Verdict: Fail

Blocking
1. tests/unit/test_mm3_qa.gd:25-29 (test_a_map_with_only_ramps_draws_nothing_and_one_on_terrain_its_ground) now fails: it pins
   Woodland's open meadow pixel to cfg.ground_colour (diff 0.146 > 0.01). FM2's tinted/shaded terrain
   (game/ui/minimap_field.gd:139 _draw_terrain, tint + relief) changes that pixel by design, and the worker did not
   update this test (it passes on 7ed6d93). Fix: compare against the tinted/relief ground (ground colour within
   ground_tint_share + relief_shade of it), or assert "is terrain, not a block colour" instead of the exact ground.

Advisory (none blocks)
- MinimapField.build on Woodland takes 816 ms against 336 ms on 7ed6d93 (depot 24/21, street 127/110): _draw_terrain does
  five height_clamped lookups per ground cell. Behind the loading screen, but the match start is ~0.5 s slower on Woodland.
- No changelog.d note and no docs/wiki change in 3929b2c (CLAUDE.md §9 wants both on a player-visible change).
- game/ui/hud_field_map.gd:161 the key box is min(needed_height, room.y): its rows are not clipped, so below ~1080 px
  of height (cannot happen with canvas_items + expand, whose smallest screen is 1920x1080) they would spill past the box.
- game/ui/field_map_overlay.gd:179 doc says a zone's word sits "inside" its box; it is placed above it. Harmless.
- A screen with no room (<= ~100 px) draws words stacked at the bounds' corner (lay_out slides inside a zero rect); unreachable.

Checked and fine: 0x0, 1x1, 120x90, 300x200, 640x360 screens (no NaN, pointer clamped, key <= 30% of content); pointer
world() maps the field's four corners back exactly on Depot, Woodland, The Street and on 2560x1080, 3440x1080 and
1920x3400 windows; pointer starts on you; one flag, no flag, no overtime flag, an end with no spawns or dead zone; practice
(no flags, no overtime spot, "Practice", empty goal); Attack/Defend half-time swap through Round.place_teams (end 0
becomes Beta's colour, goal flips to defend); Tower Block storeys 0/3/6 m (words match the floor band, none overlap);
words stay inside the field and clear of starts, dead zones, flag badges and rings on all three maps; zone words and the
compass don't overlap each other or a start/dead zone; hatch cap (64 lines) enough on all maps; rim pins on the square
panel unchanged and correct on a wide one; every key row has a word and every MAP_* string is translated; 60 resizes and
reopens add no node and no object; a frame allocates nothing on Depot and Woodland (ping, heard patch, moving pointer);
nobody heard means no enemy dot or patch; range: HUD never builds a field map (hud.gd:441 null guard).

Tests added (tests/unit/test_fm2_qa.gd, 25 tests, 11899 asserts, all pass; the new-API ones fail on 7ed6d93 because
frame_rect, FieldMapMarks, FieldMapOverlay and FieldMapKey do not exist there)
- :73 tiny/zero screens, :95 no room is not framed · :104 pointer corners to world on 3 maps · :129 start on you (wide) ·
  :140 outside-field pointer finite · :149/:162 rim pins square / wide (square pin = old behaviour, wide fails on a square-only pin)
- :178 one flag + no overtime + no spawns · :199 no flags · :212 practice · :227 half-time swap · :249 drawn round header
- :262/:281 Tower Block storeys and floor bands · :299 words clear of marks · :323 lay_out fuzz (40 seeded rounds) ·
  :351 lay_out oversize word · :359 hatch cap · :372 key rows/words · :388 key height at 1080p · :402 leak after 60
  resizes/reopens · :424 zero allocation Depot/Woodland · :445 hearing rule · :455 zone words/compass · :482 odd aspect ratios
Each fails when its rule is broken (e.g. swap not applied, _half square-only, words overlapping) by construction; I did not
mutate production code (QA never edits game/).

Runs (one file at a time): fm2_qa 25/25, fm2_field_map 12/12, fm1_field_map 15/15, fm1_qa 21/21, hud_minimap 17/17,
minimap_field 11/11, mm1_qa 10/10, mm2_qa 9/9, mm3_qa 13/14 (the failure above), mm4_qa 16/16, bushes 38/38, dp4_qa 7/7,
hud_size 12/12, minimap_hearing 11/11, ping_markers 22/22, pn2_qa 8/8, rg1_qa 20/20, squad_follow 13/13, two_flags 18/18.
tools/smoke_test.sh: PASS, zero script errors. Full suite and tools/check.sh not run (as instructed).
Not testable headless (owner's list): how the map looks at 1080p/1440p/ultra-wide (tint, relief, label legibility, hatch,
badge placement), the key's look, and a real window resize.
