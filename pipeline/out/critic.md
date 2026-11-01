Task: BQ3 · Bots play as a team and fight smarter (no task block; judged against the brief and PR #169)
Attempt: 4 of 4
Head: 6ce6391 (checks passed on it: CI per the brief; second critic pass after 0124ad2)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence for the passes (this pass reads git diff 0124ad2..HEAD; the rest stands from the first pass):
1. Brief met as before; the knee now only where it has the shot (bot_combat.gd:165-167, bot_movement.gd:611). Shipped-
   code A/B 75/45 (62 %) Depot, 62/57 (52 %) Street, Normal; 137/239 = 57 % overall, matching the changelog's "about
   57%". Street is near noise and Hard was not re-measured; both are recorded, not hidden.
2. No contract touched: one ray via BotSenses.line_clear on WorldQuery, commands only (cmd.crouch).
3. _knee_has_shot (bot_combat.gd:180-183): Vector3 values, one ray plus the existing foliage depth, only for
   kneels_to_fire skills and only when a burst begins or resumes; follow_on adds one int compare. No allocation.
4. test_bq3_qa "a burst picked up again behind low cover" presets knee_clear = true with burst_left 0.3: without
   04708eb's recheck it would crouch and fail. test_bq3_team_play:164 fails without _knee_has_shot; :217-220 (empty
   magazine) fails without the mag() > 0 gate (bot_brain.gd:241).
5. Rule in plain classes (Bot field, BotCombat static); typed; crouch fraction 1.0 is Character.eye_height's full knee,
   not tuning; _aim_point is the existing per-call scratch.
6. Kneeling only where the knee sees over the wall is better airsoft (nobody ducks behind a barricade to shoot it);
   a follower reloading before it moves on is what a player does.
7. The four pressing descriptions now say eliminations ahead (bot_config.gd:289-290, bot_skill.gd:71-72,
   game/ai/README.md:33, docs/wiki/Bots.md:56). knee_clear reset in Bot.reset (bot.gd:310).
8. Record updated (attempt 4, A/B rows, defaults); test_df2_qa's nav floor is test upkeep for the radio's rng draw.
Advisory (non-blocking): a new contact mid-burst zeroes burst_left (bot_senses.gd:148) while bursting is still true,
   so the next burst at the new target skips the recheck and can kneel one tick on the old answer before the blocked
   line stands it up again; recheck also when a burst is picked (bot_combat.gd:163) if it shows in play.
Records: set the Review line to "critic Accept 8/8"; pipeline/out/qa-report.md (b8b7ee2) and performance.md (3597106)
   predate the knee recheck: the record's QA row is the only trace of QA's Pass; I read the perf-relevant hunks.
Owner should test in the game:
- Normal bots behind waist-high cover: do they stand and fire over it, and still kneel for bursts in the open?
- The knee per burst (0.15 s down, 0.25-0.55 s bursts): a knee, or crouch bobbing that hides heads?
- Spotted by one bot: do others arrive about 1-1.6 s later in a way that reads as a call, not wallhacks?
- Two eliminations up, a team hunts the rest: aggressive and fun, or reckless?
- 1v1 endings: does the careful last bot walk so slowly that rounds time out?
- Follow Me: a follower with an empty magazine reloads in cover, then catches up?
