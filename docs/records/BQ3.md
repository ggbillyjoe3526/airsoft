# BQ3 · Bots play as a team and fight smarter

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | ✓ | see the Review line | – |

## Goal

The owner's playtest (2026-11-01): "The AI should be smart and tactical and aim to win the round/match" and "Go over
all of the bot AI (both friendly and enemy) and improve the quality as much as you can." Measured, not guessed: a
change stays only if bots with it win more rounds against bots without it.

## Approach

- **How bots got hit** (a scratch count over 4 Normal matches each on Depot and The Street, about 240 hits a map):
  about two in three hits landed on a bot in a fight that had seen its shooter, mostly while it sidestepped standing
  up (crouched in under 5 %); most were alone. So the open fight and the team's news were the places to work.
- **A knee to fire** (`BotSkill.kneels_to_fire`, `BotMovement._strafe`): fighting in the open, a bot takes a knee
  for each burst and sidesteps only between bursts, so its BBs leave from a still, crouched stance (Accuracy) and less
  of it shows while it shoots. Fighting from cover is unchanged.
- **Team radio** (`BotRadio`): a bot that sees an enemy afresh tells its teammates within `share_radius` (35 m Normal,
  45 m Hard) after `share_delay` (1-1.6 s Normal, 0.5-0.9 s Hard), each taking it as a teammate's call heard there,
  unless it is fighting, sees someone, or has fresher news.
- **Pressing a lead** (`BotWorld.pressing`): a team `BotConfig.press_margin` (2) or more players ahead in an
  Elimination round stops holding its lane and hunts.
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

  Normal wins clearly more; Hard about evens (it already held angles and traded), so its edge is small.
- `test_bq3_team_play` (the radio told near and late, not to the far, the fighting, the enemy or the caller; a caller
  out says nothing; Easy has none; pressing and the careful last bot in Elimination only; a knee for each burst and up
  between; Easy keeps sidestepping), `test_tl1_qa` and `test_bot_difficulty` unchanged in what they pin.

## Known issues left

- None.
