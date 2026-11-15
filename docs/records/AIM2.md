# AIM2 · Bots notice you like a person would, and flinch when you shoot back

**Review:** 2 attempts · critic Accept 8/8 · qa Pass (attempt 1, cee0f90) · performance Pass (attempt 1, e76d160)

The owner's 2026-11-15 ask, after AIM1: "Go over all the bot ai and logic so their reaction, aim, accuracy, etc, are
realistic and fair. Scale up and down for difficulty levels."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | The flinch's effect on aim() had no test |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## What was found

Going over sight, reaction, aim, lead, bursts and hearing per level (`bot_senses.gd`, `bot_aim.gd`, `bot_combat.gd`,
`bot_hearing.gd`, `bot_tuning.tres`):

- **A bot reacted as fast to someone at the edge of its view 50 m off as to someone right in front of it.** The
  reaction (`BotSkill.reaction_time`) started the moment the sight ray passed, wherever in the view cone and however
  far. A person notices what is in front of them first, and movement before stillness.
- **Shooting back changed nothing about a bot's aim.** A near miss (`BotHearing._near_miss`) told the bot where you
  were and put it under fire, but its aim stayed as steady as if nobody were shooting at it. In airsoft a BB past the
  ear makes anyone flinch; it is also the player's main answer to a bot that has already seen them.
- Everything else scaled sensibly per level and is left: Easy to Hard tighten aim error, settle time, tracking, lead
  and bursts step by step; Hard's edge on reaction is pre-aiming the corners it holds (0.18 to 0.28 s), "careful, not
  twitchier", and it is no quicker than Normal when surprised (`test_bot_angles` pins that, by design). Normal's fresh
  reaction (0.25 to 0.45 s) is a fair human figure. Lead tracking over time was tried and dropped (see Decisions).

## The fix

- **Noticing (`BotSenses.notice_time`):** a fresh sighting is answered later, on top of the level's reaction: up to
  `notice_edge_time` (0.3 s) at the edge of the view (by the square of how far off the middle, so near the middle it
  is small), up to `notice_far_time` (0.25 s) at `view_distance`, half of that for someone moving at 1.5 m/s or more,
  and none within `close_awareness`. The same at every level: it is how anyone sees (DECISIONS 2026-10-01, difficulty
  is skill, never senses). A re-pick-up (AIM1) has none: the bot already knows where you are.
- **Flinch (`BotCombat.flinch`):** an enemy BB landing within `suppression_radius` adds `aim_error_under_fire_deg`
  to the bot's aim error, easing to none over `flinch_time` (0.6 s). Easy 2.5°, Normal 2.0°, Hard 1.5°.

## The numbers

`tests/balance/aim_bench.gd`, 200 seeds a case, the bot looking straight at the corner (so only the distance part of
noticing shows; a corner at the edge of its view adds up to 0.3 s more). AIM1's head against AIM2, share of trials
the bot hit you, and the median time to its first hit standing in the open:

| Case | Easy | Normal | Hard |
|---|---|---|---|
| 10 m, step out 0.6 s | 0 → 0 % | 0 → 0 % | 61 → 49 % |
| 10 m, step out 1.0 s | 6 → 3 % | 36 → 24 % | 74 → 72 % |
| 10 m, run across 4 m at 4.2 m/s | 10 → 9 % | 19 → 15 % | 49 → 45 % |
| 10 m, second peek after 0.5 s | 1 → 1 % | 3 → 2 % | 24 → 22 % |
| 10 m, stand out: first hit | 1.68 → 1.73 s | 1.15 → 1.23 s | 0.53 → 0.60 s |
| 20 m, stand out: first hit | 1.98 → 2.05 s | 1.60 → 1.73 s | 1.25 → 1.40 s |
| 30 m, stand out: first hit | 2.22 → 2.30 s | 1.92 → 2.10 s | 1.57 → 1.80 s |
| 30 m, step out 1.0 s | 0 → 0 % | 0 → 0 % | 14 → 0 % |

The first trigger pull comes 0.05 to 0.18 s later, more the further away. The flinch is not in the bench (you don't
shoot back there); in matches both teams play it.

## Decisions

- **Noticing is the same at every level; the level's reaction comes after it.** Difficulty stays skill, never senses.
- **Hard's surprised reaction stays Normal's.** A quicker one (0.2 to 0.38 s) was tried: it changed nothing in the
  bench (Hard answers there from a pre-aimed corner) and broke the rule `test_bot_angles` pins, that Hard is careful,
  not twitchier. Reverted.
- **Tracked lead dropped.** Leading on velocity smoothed over time raised hits on crossing targets, the opposite of the
  ask; the lead stays as it was (`lead_factor` per level).
- **A pre-aimed Hard sighting notices as anyone does too** (QA's note): noticing comes before every reaction, the
  pre-aimed one included; Hard's pre-aim still answers 0.07 to 0.27 s sooner than a surprised one.
- **Steady fire keeps a bot flinching:** every near miss starts the 0.6 s again, so a bot sprayed at from 20 m stays
  about 0.7 m off. That is the point of shooting back; whether it makes bots too easy to pin is a play check (N15).
- **The flinch rides on the near miss already there** (`suppressed_at`, `suppression_radius`), so a teammate's BBs
  never make a bot flinch, and a round's reset clears it with the rest.

## Verified

- Bot matches, `SEEDS=16 LEVELS=normal tools/balance.sh depot` (6v6), measured on 621588b with the AIM2 game code
  uncommitted (the same as e76d160's; only a divide-by-zero guard came after): Elimination Alpha 56.2 % ±4.5 (band 45 to 55,
  outside within noise; the west end 51.2 %), no round to the clock, median round 49.2 s (47.7 s on AIM1), first hit
  15.3 s at 12.9 m (14.7 s at 14.5 m); Attack / Defend attackers 50.0 % ±4.6; Plant The Bomb attackers 42.6 % ±4.5
  (band 40 to 65). Both teams play the same rule.
- `test_aim2_notice` (new): straight ahead close by is noticed almost at once, the view's edge and the far end are
  slower by their configured times, a runner is noticed in half the time, within `close_awareness` there is nothing to
  notice, and the flinch eases off and is smallest on Hard. QA's `test_aim2_qa`: no flinch on a new or reset bot, no
  NaN at the edges, a fresh contact waits the notice time and a re-pick-up doesn't, noticing is level-blind, and
  (attempt 2) `BotCombat.aim()` itself settles the level's whole flinch further off after a near miss, least on Hard.
- `test_bot_angles` measures the level's reaction past the noticing; `test_tl1_qa` skips the new skill field.
- 100 bot test files (1,223 tests) pass.

## Known issues left

- None new.
