Task: MT2 · QA commit ae80841 · Verdict: Pass

Blocking: none. Advisory:
- game/ai/bot_lifts.gd:49-57 (aboard branch): a bot aboard resets lift_wait and just stands, so a car holding more than LiftConfig.capacity (4) buzzes forever if bots all board together (_room_aboard counts at decision time; 3 aboard + 2 boarding the same tick = 5). Needs 5 bots on one car; not reproduced, no test.
- game/sim/lifts.gd:276 area (_next_stop) and :178: a character who ends up on a car's roof (only by jumping into a shaft) is not carried (holds() is the cabin only) and the roof box rises into its feet; not reachable from Kingsmere's walkable space, not tested.
- Use near a lift landing always presses the lift first (simulation.gd:175); a hinged door within reach of a call button would never open by Use. Kingsmere has no doors, so no effect today.

Tests added (tests/unit/test_mt2_qa.gd, 8, all pass; log pipeline/out/qa/test_mt2_qa.log):
- :46 press while MOVING is kept as a call, ride finishes, car returns; fails if _press_button dropped the call bit while moving (stop != lifts.stop path).
- :63 two cars called at once ride independently (bits 1 and 4, both riders land on their floors); fails if Lifts shared one car state.
- :80 a hit player's press calls nothing; fails if press moved out of the in_play branch (simulation.gd:175).
- :93 start_match mid-ride: every car open at start stop, calls/caller/to/rise cleared, prev_y==y (no glide), doorway clear, second ride works; fails without lifts.reset in start_match.
- :123 prev_y is last tick's y and y-prev_y==rise each tick; fails if step did not set prev_y first.
- :137 jumping on a rising car never puts the feet under the floor and lands at the upper landing; fails if carry lacked the max(floor) clamp.
- :158 Depot/Woodland/Range have no lifts; a lift-less sim keeps lift state at 0, press returns false, pick is NONE, Use still steps without error.
- :188 a bot waiting on a landing for a car held open by a body in the hall doorway gives up (route WANTED) within lift_patience.
"Fails without" was reasoned from the code paths above, not by stubbing (production code is read-only for QA).

Suite: only test_mt2_qa.gd run (8/8, 106 asserts, a few seconds); full suite, check.sh and smoke were run by the caller (all pass) and were not repeated.
Not tested (needs display/window): lamp/probe look, HUD prompt layout in window modes, mouse capture, focus loss with LiftView, node counts across menu round trips (LiftView has no tweens, timers or signal connections by grep).
