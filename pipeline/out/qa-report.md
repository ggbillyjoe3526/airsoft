Task: WR1 · QA head c7e8c44 · Verdict: Pass

Blocking: none.

Checked:
- Generated data: build_map.py rebuilt data/maps/woodland.json byte for byte (947 blocks, 99 foliage, 244 areas); check.py TOTAL 0.
- Nav slope fix, probed on planes 0.4 to 0.6 a metre per axis: up to 0.53 per axis drop_on_line false, clear_line true and find_route succeeds, both directions and across the contour; at 0.6 (a diagonal over 0.75) the diagonal stays a drop, as designed (about 2% of Woodland's ground, mostly the stream banks). STEP_OF indexing, the or/and precedence in _link and the _between side cells are right.
- Off-leg replan: off_leg_at starts INF and is reset in Bot.reset, so the first ask always passes. A bot shoved within 0.5 m of its last ask towards a real drop walks on; stuck_time is the backstop (accepted, as the comment says).
- Cover: the sink test fails without the change (a crate sunk 0.3 m was dropped).
- test_terrain's slope/kerb test, test_held_up_measure's hunt test and test_woodland_layout's checks fail without their fixes and test what they claim.

Advisory (dealt with by the worker on attempt 2): stale comments naming the old wood (match_guard, match_runner, game/map and game/nav READMEs, loading_screen, play_session, game/ai README, nav_config, KNOWN_ISSUES WL3 and WL10 rows); Woodland's guards play by night only (now noted in the record); the held-up measure is weaker for hunters whose goal keeps changing (the within-reach rule still catches pacing); the changelog note and the record's Review and Checks lines were owed; the load cost is documented in KNOWN_ISSUES.

QA: Pass
