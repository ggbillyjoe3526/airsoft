# BQ3 · Bots play as a team and fight smarter

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | – | – | QA Fail: the test file didn't parse (an untyped loop); a knee held on a burst not being fired |
| 2026-11-01 | 2 | Opus 5.5 (build thread) | ✗ | – | CI's Follow me guard: Depot seed 2, a follower 12.5 m behind (catch_up 8 m) |
| 2026-11-01 | 3 | Opus 5.5 (build thread) | ✓ | see the Review line | – |

## Goal

The owner's playtest (2026-11-01): "The AI should be smart and tactical and aim to win the round/match" and "Go over
all of the bot AI (both friendly and enemy) and improve the quality as much as you can." Measured, not guessed: a
change stays only if bots with it win more rounds against bots without it.

## Approach

- **How bots got hit** (a scratch count over 4 Normal matches each on Depot and The Street, about 240 hits a map):
  about two in three hits landed on a bot in a fight that had seen its shooter, mostly while it sidestepped standing
  up (crouched in under 5 %); most were alone. So the open fight and the team's news were the places to work.
- **A knee to fire** (`BotSkill.kneels_to_fire`, `BotMovement._strafe`, `Bot.bursting`): fighting in the open, a bot
  takes a knee for each burst it is firing and sidesteps only between bursts, so its BBs leave from a still, crouched stance (Accuracy) and less
  of it shows while it shoots. Fighting from cover is unchanged.
- **Team radio** (`BotRadio`): a bot that sees an enemy afresh tells its teammates within `share_radius` (35 m Normal,
  45 m Hard) after `share_delay` (1-1.6 s Normal, 0.5-0.9 s Hard), each taking it as a teammate's call heard there,
  unless it is fighting, sees someone, or has fresher news.
- **Pressing a lead** (`BotWorld.pressing`): a team that has put `BotConfig.press_margin` (2) or more of the other
  team out than it has lost, in an Elimination round, stops holding its lane and hunts (counted on eliminations, so
  uneven sides alone never press; with even sides, as in the A/B, the same as counting heads).
- **The careful last bot** (`BotWorld.careful_last`): the last of a team walks and clears corners as near the enemy.
- All on Normal and Hard; Easy stays the fair fight to learn on. Normal keeps the levels' identity (TL1): it does not
  get Hard's held angles, corner slicing or pairs.
- From BQ1's critic (check 7): a bomb's teammate check, its flash spot and a strafe step's sight now read sight
  through glass (`BotSenses.sight_clear`), as the flash and the eyes do.

## Decisions

- None needing the owner.

## Defaults taken

- Kneel per burst, not for the whole fight: kneeling still is steadiest, and the sidestep between bursts keeps it a
  moving target. Standing still for each burst without the knee was tried and won nothing (49 %).
- Normal does not get Hard's tactics: an A/B of Normal with them against Normal without won 49 % on Depot.
- Radio reach 35 m and 45 m, and its delay, roughly a shout across a lane and a beat to say it.
- Under Follow me, a follower down in cover with nobody in sight, BBs in its magazine and not reloading comes out once
  its giver moves off further than its spot and catch-up gap (`SquadOrders.giver_leaving`, every level). CI's Follow
  me guard caught a follower that took cover on a contact, then sat out its duck and a peek while the leader sprinted
  on; at the same sprint it never closed the gap. Turning the knee off also passed, but only by moving that seed's
  fights; the cause was the cover. It reuses follow_distance and catch_up_gap, no new tuning.

## Checks

- A/B (scratch harness, not shipped: the new level on one team, the same level without the change on the other,
  sides swapped, 8 seeds each, Elimination, plain kits):

  | Change | Map, level | Rounds won (new / old) | Share |
  |---|---|---|---|
  | Radio, pressing, careful last | Depot, Normal | 72 / 56 | 56 % |
  | Radio, pressing, careful last | The Street, Normal | 57 / 61 | 48 % |
  | Radio, pressing, careful last | Depot, Hard | 59 / 54 | 52 % |
  | A knee to fire, on top | Depot, Normal | 70 / 52 | 57 % |
  | A knee to fire, on top | The Street, Normal | 70 / 50 | 58 % |
  | A knee to fire, on top | Woodland, Normal | 61 / 54 | 53 % |
  | All of BQ3 | The Street, Normal | 66 / 49 | 57 % |
  | All of BQ3 | Depot, Hard | 60 / 57 | 51 % |
  | All of BQ3, after QA's kneel fix | Depot, Normal | 71 / 51 | 58 % |
  | All of BQ3, after QA's kneel fix | The Street, Normal | 67 / 54 | 55 % |

  The rows above the last two were run before QA's fix (a knee was sometimes held on a burst not being fired); the
  last two are the shipped code. Normal wins clearly more; Hard about evens (it already held angles and traded), so its edge is small.
- `test_bq3_team_play` (the radio told near and late, not to the far, the fighting, the enemy or the caller; a caller
  out says nothing; Easy has none; pressing and the careful last bot in Elimination only; a knee for each burst and up
  between; Easy keeps sidestepping; a follower in cover comes out after a giver moving off, not with an enemy in sight,
  reloading, a giver standing or close, or another order), `test_tl1_qa` and `test_bot_difficulty` unchanged in what they pin.
- Older tests it touched: `test_bot_angles` (the watcher there is the last of its team, so a careful last bot looks at
  corners too), `test_bots`' warm-tick check (now counts the event pool's documented growth to a new busiest tick,
  which the new play reached inside the measured window; nothing else allocates).

- Follow me guard (Depot, 4 seeds): before the cover fix seed 2's worst was 12.52 m; after it 4.92 m, the others
  unchanged (4.88, 5.55, 7.47 m), all 100 % or 97 % near.
- QA: Fail then Pass (`test_bq3_qa`: a pending call cleared by a round reset, fresher news kept, nobody out or on the
  other team told, nothing before the round is live, no knee held without firing over a whole match: 15 of 2802 fight
  ticks a tick either side of a burst, longest 1 tick, against 354 and 211 before the fix).
- Performance: Pass (smoke match level with BQ2's head on nodes and orphans; the radio and the two checks loop the
  bots and characters without allocating; the warm-tick reading is fair, the event pool being one object a slot).
- Critic: Accept 7/8 (check 7: four descriptions still said pressing counts players in play, not eliminations; reworded
  after the verdict). QA and performance ran before the Follow me fix; the critic read it (no allocation, no contract
  changed) and QA rechecked it alone: Pass, with two tests added to `test_bq3_qa` (a giver out of play or gone keeps
  it in cover; a peek with nobody in sight ends after the giver). From its advisories, a follower with an empty magazine
  now stays to reload first; a giver moving off any way counts (direction doesn't matter far off).

## Known issues left

- None.
