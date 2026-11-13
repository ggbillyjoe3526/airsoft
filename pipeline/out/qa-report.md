Task: MB4 · QA commit none (uncommitted tree; my test tests/unit/test_mb4_qa.gd is untracked, not committed per instructions) · Verdict: Pass

Blocking: none.
Advisory:
- game/ai/bot_combat.gd:364 (leaves_in_line, BU1) vs the real Brow hazel: two opposing bots 0.7 m apart at (-16.3, -40.5) are still held for the leaves (eye 1.5 m up, chest line; depth over the shortened line 0.6+ m > leaf_stop_depth 0.6). They fire up to about 0.66 m apart. Not a deadlock: the bots walk into each other and unlock 4 cm on. The build thread's night seed 14 (held_up 0) and test_mb2_qa show it plays clean. Worth a KNOWN_ISSUES note if a pair is ever seen stuck at 0.7 m.
- docs/records/MB4.md "Known issues" says the Woodland Attack / Defend row is brought up to date; the diff does not touch that row (AD_BUILT is pending, so expected).

Criteria:
1. Met. data/maps/woodland.json is byte-identical to 85e3f52 (cmp); build_map.py rerun leaves it identical (deterministic); check.py prints TOTAL 0. Against HEAD the JSON differs in one line (single-line file), and the word diff shows only the one hazel entry's z (-38.2 to -40.5). layout.py hunk matches.
2. Not mine to re-run (matches). Recounted from pipeline/out/mb1: built eh+ehb+ehc+ehd = 117 of 246 = 47.6 % (draws left out); rc16..rc16d 114 of 240 (47.5); ef..efd 95 of 231 (41.1); ef..efh 203 of 476 (42.6, record says 177 of 418 over seeds 1 to 56, a different subset, not rechecked); eg..egd 120 of 236 (50.8). All table figures match.
3. Pending (AD_BUILT, not reported).
4. Met. test_mb2_qa 7/7 (155 s), test_mb1_layouts 9/9 (174 s), test_bushes 39/39, test_bu1_point_blank_bush 4/4. Outputs in pipeline/out/qa/mb4-*.txt. Night seed 14 replay is the build thread's figure; I did not rerun it.
5. Met. test_mb4_brow.gd 3/3 (6 s), gdlint clean. Critique: sight test is honest (9 eye points x 3 targets = 27 lines, stand eye height, leaf depth vs ballistics leaf_stop_depth, solid ray first), seed-free, not flaky. Test 1 (one bush within 0.2 m) fails for any move over 0.2 m, so a 1 m move is caught by it; the sight test alone might not catch a 1 m move (not tried: I may not alter the map). Test 3 (lane passes within 6 m) is loose; it guards the route, not the hazel. No tautology found.
   Verified the record's claim only by reading, not by stubbing (cannot swap the map file).

Tests added: tests/unit/test_mb4_qa.gd:32 · test_two_opposing_bots_pressed_together_in_the_brow_hazel_have_a_shot · on the real Woodland query, two bots 0.5 m apart at the hazel have a shot under BU1's rule. Fails without BU1 (leaves_in_line held the pair; the held case at 0.7 m shows the leaves are really there), but passes with the hazel moved (no leaves), so it pins BU1 on the real bush, not the hazel's place. 1/1 passing, gdlint clean.

Docs: KNOWN_ISSUES Elimination row deleted and "by team" row figure (47.6 % ±3.2, 117 of 246) true; DECISIONS MB2 entry sentence true (41 % wording changed to "took", MB4 sentence matches).

Counts: files run 7, all passing (63 tests). tools/check.sh and the smoke test not run (one godot at a time, busy machine, per instructions).
Could not test: full unit parts, smoke test, match guards, a moved-hazel mutation (map file off limits), feel of the Ridge brow in play (owner).
