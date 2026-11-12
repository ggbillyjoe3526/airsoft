# SH1 · The Pump Shotgun

**Review:** critic REVIEW_CRITIC · qa REVIEW_QA · performance REVIEW_PERF

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (build thread) | ATTEMPT_CHECKS | ATTEMPT_CRITIC | – |

## Decisions

- **The owner's ask and answers** are in `docs/DECISIONS.md` › The Pump Shotgun: spring, three BBs a pull, a 30 BB
  shell swapped like a magazine, the Sniper Rifle's springs, the default parts, a full stock, level 12.
- **The id.** `SH1` (this, the gameplay) and `SH2` (its model): `SG1` was the scope's glass at the hip.
- **What makes it its own.** The first pull wins: three BBs leave as an even triangle round the shot's line, so an
  aim that is a degree off still lands inside 15 m, where every other replica needs a second shot or a burst. It
  pays with a pump after every pull (1.7 pulls a second), the shortest reach of any long replica (24 m) and nothing
  to give at range. A spring: the cold doesn't weaken it, the no-full-auto-indoors rule doesn't touch it, and with
  the M130 it is heard from 0.85 of the distance.
- **Two new replica fields,** `shot_bbs` and `pattern_deg` (`data/stats.md` columns "BBs per shot" and
  "Pattern (°)", both optional, 1 and 0 for every other replica). `Armament._fire` sends `shot_bbs` BBs (or what the
  shell has left), each off the magazine, each with its own scatter, spaced evenly round the line with the first
  straight up. A single-BB replica draws the same random numbers as before (a test pins its first shot).
- **The pump reuses `bolt_action`** (one pull a click, the hand cycle heard after the shot); the bots' bolt-action
  aim settle is for single-BB replicas only, and a bot with a pattern holds its pull past where the pattern is wider
  than `BotConfig.pattern_hold_radius` (0.6 m: about 29 m at 1.2°).
- **One hit is one hit.** Nothing new: a body that is already calling its hit stops later BBs without a second hit
  (a test: three BBs into one bot, one CHARACTER_HIT).
- **The numbers,** from the flight model (`Ballistics`), a hit-chance bench and bot matches:

  | | Pump Shotgun | M140 | M150 | for scale |
  |---|---|---|---|---|
  | Energy (J, 0.20 g) | 0.65 | 0.72 | 0.78 | SMG 0.85, GBB Pistol 0.70 (PH2) |
  | Muzzle (fps) | 265 | 277 | 290 | |
  | Pulls a second | 1.7 | 1.61 | 1.53 | Sniper 1.0 |
  | Reach (m), as it comes / best hop | 24 / 28 | 25 / 30 | 27 / 32 | Pistol 29, SMG 30 (PH2), AEG 39 |
  | Kick (°) | 0.45 | 0.54 | 0.68 | |

  A 30 BB shell is ten pulls; five shells carried (50 pulls); reload 1.2 s; raised in 0.5 s; hip spread 0.7 of the
  rifles' (it is fought from the hip).
- **The pattern is 1.2°,** not the 0.83° first estimated to the owner (25 cm apart at 10 m): the hit-chance bench
  (one pull or one shot at a standing figure, 4,000 tries a cell) showed 0.83° still landed half its pulls at 30 m.
  At 1.2° the BBs are 36 cm apart at 10 m and 73 cm at 20 m:

  | Aim error 1°, aimed, standing | 5 m | 10 m | 15 m | 20 m | 25 m | 30 m |
  |---|---|---|---|---|---|---|
  | Pump Shotgun, one pull | 100 % | 95 % | 83 % | 67 % | 53 % | 41 % |
  | AEG or SMG, one shot | 97 % | 70 % | 47 % | 33 % | 25 % | 20 % |

  With 2° of error: 89, 64, 46 and 34 % at 5 to 20 m against 71, 33, 20 and 13 %. From the hip on the run with 1°:
  100, 85, 63 and 48 % against the SMG's 91, 56, 36 and 25 %. The autos stay far ahead in hits a second (the SMG
  12.6 a second at 10 m against 1.6).
- **Bot matches** (6v6 Elimination, Normal, five seeds a map, every kit at the same weight plus the Clearer with the
  M150 and with no optic; hits per hit taken): Depot Clearer 1.18, bare 1.14, M150 1.38 (Support 1.05, Pointman
  1.08, Breacher 0.92, Rifleman 0.78); Subway Clearer 1.09, bare 1.24, M150 0.76 (Support 1.32, Breacher 1.21,
  Stealth 1.12, Rifleman 0.80). Woodland Clearer 0.30, bare 0.33, M150 0.32 (Rifleman 1.77, Breacher 1.46,
  Support 1.34, Sniper 0.68; its median hit there is at 27 m, the rifles' at 40). So it sits with the close kits
  indoors and is the weakest thing to carry in the open, which is the trade it was given; about twenty bot-rounds a
  row for the spring and optic rows, so those are a direction, not a figure.
- **The benches ran before PH2** (#327, merged the same evening) raised the GBB Pistol to 0.70 J and the Compact SMG to
  0.85 J: their BBs fly quicker now and their spread is as it was, so the one-shot rows above hold, and the Breacher
  and the pistol kits will stand a little better beside the Clearer than the bot matches show. The Dev 3 balance pass
  runs them again.
- **The bot kit** is the Clearer: a Red Dot, a GBB Pistol, two flashes, rushers and flankers, weights 3, 6 and 8
  (Easy, Normal, Hard) beside the Breacher's.
- **Its model is the Sniper Rifle's** until SH2 builds its own from the owner's five photos (saved in the project
  files, `art/references/shotgun/`). The stand-in has no laser's place, so the side rail (the Red Laser's) joins
  `data/pool.md` with the model; it takes every optic, the Weapon Torch (which fits any rifle, drawn at the Sniper
  Rifle's mount for now) and the springs now.
- **Stand-in sounds** (`tools/cut_recordings.py`, marked there): the shot is the owner's sniper shot pitched down and
  cut short, the pump his sniper bolt squeezed to the pump's 0.59 s, the shell out and in his cover clicks pitched
  down. What to record is in the project files' `audio/record-next.md`, the state in `audio/sound-status.md`.
- **The Loadout's sheet** shows its rate as "1.7 × 3" and a Pattern row no other replica has (a row in
  `ABOVE_ZERO_ROWS` shows only above 0).
- **The wiki** prints its rate as "1.7 shots/s, 3 BBs each" (`tools/wiki.py`); it is Dev content, so it shows only
  on Roadmap.

## Known issues left

- Drawn, held and pictured as the Sniper Rifle; no Red Laser yet (SH2). `docs/KNOWN_ISSUES.md`.
- Its sounds are stand-ins until the owner records them. `docs/KNOWN_ISSUES.md`.
- Balanced on benches, not by play: the Dev 3 checklist asks the owner how the first pull, the pump's pace and the
  pattern's width feel. `docs/KNOWN_ISSUES.md`.
- Bots lead a mover with the pattern's centre as with any replica; they don't yet choose a doorway fight because
  they carry it.
- Bots pick the Clearer kit on any field, so on Woodland the few who carry it are out-ranged (0.30 hits per hit
  taken): kits have no lean by field yet. `docs/KNOWN_ISSUES.md`.
