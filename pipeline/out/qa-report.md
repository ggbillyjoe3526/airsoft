Task: BQ1 · QA commit (see git log, Agent: qa) · Verdict: Fail

Blocking
1. game/ai/bot_combat.gd:143-150 (Bot.no_shot_for) · no_shot_for is cleared only where shoot() gets past the `ready` / fire-cone early return. A bot that pushes in (BotPersonality.pushes_in: SEARCH sprints, brain line 77/84) and went round after 1.5 s of glass keeps `no_shot_for` >= no_shot_move_after for as long as it sprints: cmd.sprint makes `ready` false, so the `b.no_shot_for = 0.0` after the line-of-fire check is never reached. `seeing` in bot_brain.gd:122 stays false, so with the glass gone and a clear shot at 6 m the pusher keeps sprinting at the spot and never goes to FIGHT (and never fires) until it runs into the target. Non-pusher bots (walk in SEARCH) recover at once. Fix: reset the counter when the line is open independent of `ready` (check the level in the line before the ready/cone early return), or clear it when the mode is SEARCH and the line is clear.

Advisory
- tests/unit/test_pings.gd:544 (object count +1) fails when run after test_bq1_qa.gd in one GUT run, passes alone and after test_bq1_glass_sight / test_fm1_go_there; most likely an order effect of the failing pusher test, recheck once blocking 1 is fixed.
- game/sim/grenades.gd:395 flash check still uses ray (a flashbang behind glass blinds nobody); sound_path uses ray (glass blocks sound). Arguably right, not stated in the record.

Tests added
- tests/unit/test_bq1_qa.gd:test_a_bot_fights_again_once_the_glass_is_gone · bot goes round through glass, glass removed, FIGHT with counter 0 within 0.5 s · regression guard (passes; without the feature the `went` precondition fails)
- tests/unit/test_bq1_qa.gd:test_a_bot_that_pushes_in_fights_again_once_the_glass_is_gone · same with a pusher style, 3 s of sprinting at the pane first · FAILS (blocking 1); passes for the non-pusher control above.

Also checked, no bug (throwaway test, not committed): Go there lapse, then Go there again elsewhere, holds the full 30 s from the new arrival and lapses again; Team plan after a Go there hold gives no QUIET; Hold here pressed over a Go there hold never lapses.

Runs (13 files: fm1_go_there, bq1_glass_sight, bq1_qa, squad_orders, st1_qa, street, pings, night_sight, night_light, bot_personality, bots_hunt, bot_team_play, bot_crossfire): 130 tests, 128 pass, 2 fail (blocking 1, advisory pings count), 123 s. Did not run tools/check.sh (running in the main session). Not tested: Jolt sight ray in a real window with The Street (needs a display; owner: look through the House windows and shelter in play, bots should shoot only where the pane ends).
