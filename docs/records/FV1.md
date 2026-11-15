# FV1 · Burst indoors, field of view 87, the new volume mix

**Review:** 1 attempt · critic pending · qa Pass · performance Pass

The owner's feedback (2026-11-15): "make burst the standard fire mode indoors instead of semi", "default fov should be
87", and the new audio defaults "90 master, 80 effects, 80 power source, 30 ambience, 40 interface ... adjust power
source volumes so the current 100 is equal to 80".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ (gdlint, wiki, touched unit files, smoke test; the rest in CI) | pending | – |

## What the bots showed

Bot matches on Depot, 6v6, Normal, seeds 1 to 32 (`tools/balance.sh depot`, LEVELS=normal, MODES=elimination,plant):

| Figure | Before (main, PB4 record) | After | Band |
|---|---|---|---|
| Plant The Bomb: the attackers' share | 51.6 % ±3.2 | 47.0 % ±3.2 (118 of 251) | 40–65 % |
| Plant The Bomb: rounds armed | – | 66.5 % | – |
| Elimination: Alpha's share of decided rounds | – | 48.5 % ±3.3 | 45–55 % |
| Elimination: either end's share | – | 50.2 % / 49.8 % | 45–55 % |
| Elimination: rounds that run out the clock | – | 0 % | ≤ 10 % |

All 7 banded figures are in band, none near an edge. The attackers' share moved 4.6 points, about one standard
error of the difference (4.5 points; two would be 9), so Depot's 16 s fuse stays. Subway (a Dev map, being reworked
in its own thread) was not re-run: its fuse is re-measured on the new layout, as PB4 asks.

## Decisions

- **Indoor fields start on `burst` (data/maps.md Start mode; owner ruling in `docs/DECISIONS.md` › No full auto
  indoors).** The rule is still "the most a selector starts on": the AEG (comes on auto) starts on burst, the Compact
  SMG (semi and auto, no burst) on semi, and the Cyber, which comes on semi on every field, stays on semi. Default
  taken: the Cyber is not lifted to burst indoors, so no replica is more automatic indoors than outdoors.
- **Bots on burst pull a burst at a time** (`BotFireMode.pull`): no pull while a burst runs, the next one
  `semi_tap_gap` (0.2 s) after it ends, as a player taps. Before, a held trigger gave one burst per bot burst. About
  8 BBs a second while firing with the AEG, between semi's 5 and full auto's 13. Full auto stays as NA1 and AUD2
  set it (open ground down a long line, now and then; the Compact SMG inside 12 m).
- **Field of view 87 by default; volumes 90/80/80/30/40, the Power source bus at 1.25 times its slider**
  (`Settings.VOLUME_GAINS`, owner ruling in `docs/DECISIONS.md` › First-start defaults, 15 November). Settings
  version 4: a v1 to v3 save still on its old default moves (FOV 90, and each volume); a Power source the player set
  is divided by 1.25 so it sounds as it did; any other value the player set is kept.
- The haze thread's pull request also bumps Settings to version 4; whichever merges second takes 5 and adds its step
  on top.

## Known issues left

- None. How 87 feels, the burst start in hand and the Power source at 100 % (+1.9 dB into Master's limiter) are on
  the owner's checklist (N11).
