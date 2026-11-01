Task: BQ3 · Bots play as a team and fight smarter (no task block; judged against the brief and PR #169)
Attempt: 3 of 4
Head: 77da242 (checks passed on it: record attempt 3, CI)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 7/8 → Accept
Evidence for the passes:
1. Brief ("smarter, tactical, aim to win", friends and enemies): radio bot_radio.gd:10-47 hooked at bot_senses.gd:143
   and bot_controller.gd:107; pressing bot_world.gd:102; careful last bot_world.gd:109 + bot_brain.gd:49; knee
   bot_movement.gd:611; Follow me squad_orders.gd:163 + bot_brain.gd:241. Measured win share on shipped code 58 % / 55 %
   (Normal, Depot / Street); Hard only 51-52 % and was not re-measured after QA's kneel fix.
2. Commands only (cmd.crouch), seeded draws via b.pick, physics via sight_clear on WorldQuery; no contract touched.
3. Read the hot paths: radio, pressing, careful_last, giver_leaving loop or compare values (Vector2 is a value), no
   Array/Dictionary/lambda/new(); test_bots warm-tick change accounts only for SimEvents' documented pool growth.
4. test_bq3_team_play.gd:193 fails without follow_on (bot_brain.gd:241); :152-153 fail without the knee branch.
5. All values in BotSkill/BotConfig (.tres); static types throughout; logic in plain classes.
6. Taking a knee, team calls and hunting a lead are recognisable airsoft play; Easy left as the learning level.
8. changelog.d note, wiki Bots and Squad-Orders, FEATURES, PLAYTEST, ROADMAP, game/ai/README row for bot_radio.gd.
Failed checks, with evidence:
7. [judgment] f815d87 moved pressing to counting eliminations, but its descriptions still state the old rule:
   bot_config.gd:289 "this many more of its team in play than of the other", bot_skill.gd:71 "at least press_margin up
   in play", game/ai/README.md:33 and docs/wiki/Bots.md:56 "players ahead" (the changelog says "eliminations ahead").
   With uneven sides these differ, so the docs mislead the next tuner.
Must-fix (non-blocking, fold into the merge commit): reword those four lines to "eliminations ahead". Set the record's
Review line to this verdict (it already claims "critic Accept 8/8"). Note: QA (b8b7ee2) and performance (pre-rebase
3597106) predate 77da242's Follow me fix; I read it (one compare and a length per bot in cover, no allocation).
Owner should test in the game:
- Normal bots in the open: does the knee per burst (0.15 s down, 0.25-0.55 s bursts) read as a knee, or as crouch bobbing that makes heads hard to read?
- Spotted by one bot: do others arrive about 1-1.6 s later in a way that reads as a call, not as wallhacks?
- Two eliminations up, a team hunts for the rest of the round: aggressive and fun, or reckless?
- 1v1 endings: does the careful last bot walk the lane so slowly that rounds time out?
- Follow Me under fire from someone it can't see: does a follower leave cover and walk into the BBs?
- Hard: does it feel any smarter? It measured about even against the old Hard.
