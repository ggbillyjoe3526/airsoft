Task: BQ3 · QA commit 865e729 · Verdict: Fail

Blocking
1. tests/unit/test_bq3_team_play.gd:87 did not parse (`for id in [5, 6]`, untyped iterator, warning treated as error): GUT
   ignores the whole file, so none of BQ3's 8 tests ran. I typed it (`for id: int in`) in my commit; with that all 8 pass.
   The record's "qa Pass" line (docs/records/BQ3.md) was therefore never true; it needs updating.
2. A bot stays crouched and still on a stale burst. game/ai/bot_movement.gd:611 kneels on `b.burst_left > 0.0`, but
   BotCombat.shoot (bot_combat.gd:~148-166) returns early without touching burst_left when the target is gone, not yet
   in the fire cone, or the line is blocked by glass or leaves; burst_left also survives into the next fight (reset only on
   a new contact, bot_senses.gd:147). In 3 seeded Depot matches (Normal, 3 round lengths x6): 354 of 3041 FIGHT ticks
   (11 %) were kneeling without firing, 211 of them with the target not visible (FIGHT lingers), the longest streak 211
   ticks (3.5 s) crouched, still and not shooting. A bot out of the fight's rhythm is the easiest target. Fix (worker):
   gate the kneel on `b.target_visible and b.no_shot_for == 0.0` (and ideally zero burst_left on shoot()'s early returns).
   Note it also fires its first BB of each burst standing (the knee is applied the tick after burst_left is set).
   The owner's A/B (57 % Normal) was measured with this behaviour; re-measure after the fix.

Advisory
- Pressing is sticky: `hunting` is set once (bot_brain.gd:217) and not cleared when the lead is lost, as for pushing_late.
- Careful last bot walks the whole lane from the round start (slow); it could add round timeouts in 1v1s. Not measured.
- test_bots warm-tick check now allows object growth equal to the event pool's growth (SimEvents.items); any one-off beyond
  that still fails, so it still catches per-tick allocation. BotRadio/pressing/careful_last allocate nothing (read).

Checked, no bug: radio skips dead/out/other-team/fighting/seeing/fresher-news bots and the caller; a call due while not live
or with the caller out is dropped; Bot.reset clears share_id/share_at; Easy never draws RNG for it; pressing and careful_last
are Elimination and live only (not Attack/Defend; overtime bots are in FLAG mode); kneel is skipped for the raiser at the
pole and fighting from cover; ORDER bots take radio news as a heard noise (same path as BotHearing).

Tests added (tests/unit/test_bq3_qa.gd, 7 tests, 5 pass, 2 fail by design on blocking item 2)
- :43 · a kneeling bot is never crouched and still >= 1 s on a burst it is not firing (whole Normal match) · FAILS (211 ticks)
- :93 · Bot.reset clears a pending call · fails if the two reset lines in bot.gd are removed
- :105 · radio does not overwrite half-second-old own news · fails if the freshness guard in bot_radio.gd:41 is removed
- :130 · radio skips an OUT teammate and the other team · fails without the in_play/team filters
- :155 · a call is dropped when the round is not live · fails without the `w.live` test
- :168 · pressing and careful_last wait for a live round · fails without `live`
- :195 · a leftover burst with the target out of sight does not kneel (unit pin, fast) · FAILS
I checked the "fails without" claims by reading the guarded lines, not by stubbing them out.

Counts: test_bq3_team_play 8/8 (after the typing fix), test_tl1_qa 7/7, test_bot_angles 14/14, test_bots 16/16 (177 s),
test_bot_bombs 14/14, test_bot_difficulty 10/10, smoke test PASS. Full suite and tools/check.sh not run (about 40 min).
Logs: pipeline/out/qa/. Not testable headless: how the knee feels (owner: watch a duel on Depot; bots should stand and
sidestep between bursts, never stay low and idle).
