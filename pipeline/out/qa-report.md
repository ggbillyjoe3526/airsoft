Task: BQ2 · QA commit (see git log, "BQ2 QA tests") · Verdict: Pass

Blocking: none.

Advisory:
- game/config/callouts_file.gd (ASK_ROWS "Seen at once to need help", 0 to 10): 0 is accepted and then a bot in FIGHT/COVER asks Need help about nobody every gap (reproduced: file with 0, bot FIGHT, no contacts, asks within 2 s); 1 makes Go round unreachable (callouts.gd:351 fires first). Shipped value 2 is fine. Suggest a 1..10 range (or 2..10).
- game/ai/callouts.gd:354-362 / _round_spot: when a stand-off holds and no walkable floor is near the offset point (SquadOrders.NO_SPOT), _watch_asks reruns _round_spot every tick for every such bot (two nearest_walkable calls per side, each with an INF-drop fallback, plus the literal array `[mine, -mine]` allocated per call). Bounded to bots in a >=8 s stand-off, but it is the one per-tick allocation/search the change adds; cache the miss or skip until the enemy moves.
- Go round spot (callouts.gd:_round_spot): always on a walkable node, but nothing checks it is reachable from you, on your storey, or on your side of a wall (nearest_walkable only snaps within ask_snap). Fine for a hint ping; a Go round across a wall is possible.
- A flag-rope ask (Cover me / Need help at the pole) waits in the queue up to pace "A call waits at most" (1.5 s); a player who dies in that window is handled (the bot's call is dropped only if the bot goes out; see test), but one who walks within you_further in it is not re-checked at flush. Negligible.
- A bot's ask replaces its own still-up Contact mark in its ping slot (Pings.ask), so that contact marker vanishes. By design; noting it.

Checked, no bug found: no player (player_id -1, callouts.you null, flag rope too), enemy team never asks, your team being team 1, player out, player near, two bots in one fight (one ask per gap, one ping up), per_round cap across 120 s, round reset clears count/gap and drops a waiting ask, a stand-off with a downed enemy / no nav / enemy on top of the bot, Go round spot on the nav grid, a Contact mark never overwrites an up ask and marks again once it lapses, bots never take an ask.

Tests added (tests/unit/test_bq2_qa.gd, 10 tests, 19 asserts, 1.5 s). None can fail "without the feature" in the stub sense (Event.NEED_HELP etc. do not exist on main, the file would not parse); the ones that guard a rule fail if the rule is removed:
- :test_with_no_player_nobody_asks_and_nothing_breaks · you == null with fights and a flag rope · fails if `_far_from_you` lost its null check.
- :test_when_you_are_on_the_second_team_its_bots_ask... · team 1 asks, team 0 never · fails if the team test used a fixed team.
- :test_two_bots_in_the_same_fight_make_one_ask_in_the_gap · one ask, one ping up, none more in 20 s · fails if `_allowed` dropped the asked_at check.
- :test_a_stand_off_against_an_enemy_who_went_down / _with_no_nav / _with_the_enemy_on_top · no Go round, no throw · fail if the in-play, nav or zero-length guards were removed.
- :test_a_go_round_spot_is_on_the_nav_grid · spot is a spot and within 0.2 m of a walkable node.
- :test_a_contact_call_while_the_ask_is_up_does_not_mark_over_it · Callouts._mark with an up ask · fails if the `pings.asking` guard is removed (Pings.mark resets ask to NONE).
- :test_an_ask_waiting_when_the_round_restarts_is_never_said · flag-rope ask queued, ROUND_START same tick, nothing said · fails if `_reset` kept queue entries.
- :test_you_going_out_after_an_ask_is_offered... · player CALLING before the ask is said, no Cover me · relies on the flush in-play/bot check plus _far_from_you at offer; passes.

Runs: test_bq2_asks 11/11, test_callouts 25/25, test_pings 23/23, test_callouts_file 14/14, test_ping_markers 22/22, test_bq2_qa 10/10; tools/smoke_test.sh PASS (zero script errors). tools/check.sh and the full suite (~40 min) not run; gdlint on the new file clean.
Not tested (needs a display/play): marker legibility and how often asks feel in a real round (30 s/3 per round).
