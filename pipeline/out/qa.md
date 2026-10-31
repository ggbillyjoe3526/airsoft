Task: AB1 · QA re-check at fb65b9c (diff 395a152..fb65b9c) · QA tests committed in fb65b9c · Verdict: Pass

Blocking: none. The earlier blocker is fixed: tests/unit/test_overtime_bots.gd calls BotFlag.spot(list[0], w) in both places and parses (12 pass).
The wants_flag advisory is fixed: game/ai/bot_flag.gd now guards b.retake_pole >= 0 before indexing the flags.

Re-run on fb65b9c: test_overtime_bots 12, test_fg2_qa 6, test_ab1_qa 13, test_two_flags 18, test_bot_flag 14, test_squad_orders 14 (all pass). Earlier on 46493f3: test_so1_qa 22, test_flag_play 14, test_fg1_qa 13, test_hud_minimap 17, test_overtime_flag 19.

Verified: one-pole maps and Elimination unchanged (no retakers picked, pole 0, overtime foot used); retake_pole and flag_pole always in range; a defender is let go once its flag is on the bottom; squad-ordered bots are never sent; no pole flipping in a 100 s Depot bot match, both flags used.

Advisory (non-blocking): HUD _flag_eye is zero until the first place_flag_marker, so the first frame's "nearest pole" is measured from the origin (cosmetic). Gauge shows the pole in play, not always the one being worked.

Not run: whole suite, tools/check.sh, smoke test (CI). Owner to play: A and B read from across the hall, marker switching, warning naming the pole.
