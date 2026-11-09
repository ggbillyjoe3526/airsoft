Task: FL1 · QA commit 025070b · Verdict: Pass

Blocking: none.
Advisory:
- game/ai/bot_bombs.gd (_mate_sees): lead uses current velocity only, so a teammate who turns or stops mid-way is over- or under-predicted; press-time re-check covers the turn. Already listed in the record (bounce off unforeseen geometry).
- _mate_sees now raycasts up to twice per teammate per candidate spot; bounded by the roll gap, not per frame, so cost is fine.

Tests added: none by QA. Worker's two in tests/unit/test_bot_bombs.gd cover both behaviours:
- test_no_flash_where_a_teammate_walking_in_would_be_by_the_bang: walking vs standing mate at 16.5 m. Not re-run on main (tree shared, no checkout); by reading, the walking case throws on main because only the standing position was checked.
- test_a_teammate_stepping_near_the_bang_while_it_turns_stops_the_throw: no press-time check on main, so the throw happens; here it is dropped and the flash kept.

Runs on head: test_bot_bombs 17/17 (77 asserts, 77 s); test_sf2_qa 8/8 (47 s); test_bp2_qa 2/2. tools/check.sh not run (asked not to).
Not tested: feel of bots refusing flashes in real play (owner's list).
