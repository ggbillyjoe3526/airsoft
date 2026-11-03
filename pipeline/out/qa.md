Task: SN3 · QA commit not committed (tests staged only, left to the caller) · Verdict: Pass

Blocking findings: none.
Advisory findings:
- game/ai/bot_hearing.gd (_hit_call reveal loop): teammates within hearing_distance of the victim are given the shooter
  whatever the shooter's distance. Harmless (the reach is 70 m, and the bot must still face, see and light the target),
  but a shooter 150 m away is still "revealed". Can wait.
- game/ai/bot_combat.gd bolt_waits: the wait restarts whenever a contact lapses past contact_grace, so a sniper bot
  peeking in and out never fires on a flicker. It cannot hold for good: settling grows with the clock for as long as the
  contact lives, and with no contact there is no wait. Intended; only a feel check.
- The Street lane 2 waypoints run straight over the new bins (x -10, z 30 to 5); nav routes round them (tested), so
  no stuck bot, but the bins are in the line a middle-lane bot walks. Feel check only.

What I hunted and found sound:
- Reveal across rounds: Bot.reset clears revealed_id/revealed_until, and RoundPlanner resets every bot each round; a new
  match builds new bots.
- Shooter already out: a near miss and a hit call both check Elimination.is_in_play(shooter); a dead teammate, a victim's
  out-of-earshot teammate and a friendly hit get no reveal.
- Night and dazzle: sight_reach only lengthens the range; visible_part still applies dazzle, made_out (night) and the
  FOV and line checks, so a revealed sniper in the dark or a dazzled bot is still unseen.
- Bolt wait: bounded for easy/normal/hard (fires once reacted plus aim_settle_time x bolt_settle_share); no contact, no wait.
- Bins: solid in nav, 1.4 m clear on each side of the 3.5 m Path, routes from (-10,30) to (-10,5) avoid the footprint, and
  every Alpha spawn reaches every Beta spawn.

Tests added, tests/unit/test_sn3_qa.gd (11 tests, 87 asserts, all pass):
- test_a_new_round_clears_a_reveal · Bot.reset · fails with the two reset lines removed from bot.gd (checked).
- test_a_shooter_already_out_is_not_revealed_by_a_near_miss / _by_a_hit_call · is_in_play guards · the hit-call one fails with
  the shooter guard removed (checked); the near-miss one pins the existing guard.
- test_a_hit_call_out_of_earshot_or_on_a_dead_teammate_reveals_nothing · fails with the teammate in-play guard removed (checked).
- test_a_friendly_hit_reveals_nobody, test_a_reveal_does_not_see_through_a_dazzle, test_a_reveal_does_not_see_past_the_dark
  · fail without the feature only in the sense that a reveal bypassing dazzle or night would break them (not mutated).
- test_the_bolt_wait_always_ends, test_a_bolt_bot_with_no_contact_does_not_hold_fire · bolt_waits is finite for three skills.
- test_the_path_bins_leave_the_path_walkable_both_sides_and_end_to_end, test_every_spawn_still_reaches_the_other_end_of_the_street
  · nav on the regenerated street.json; fail if the bins sealed the Path or a spawn.

Runs (single files, all green): test_sn3_qa 11/11, test_pn1_qa 4/4, test_sniper_rifle 11/11, test_night_sight 12/12 (20 s).
Not run, as instructed: test_street, test_field_layout, test_bp3_balance, tools/check.sh, the smoke test.
Not testable here: how the bins and the 4 s reveal feel to play, and the sniper-bench balance figures (owner's playtest list).
