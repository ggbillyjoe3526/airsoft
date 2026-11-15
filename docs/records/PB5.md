# PB5 · Plant The Bomb's fuses measured again on the reworked fields

**Review:** 1 attempt · critic pending · qa pending · performance pending

The owner's ask (2026-11-15 09:53): the Plant The Bomb balance thread rebalances once the map reworks are in. PB4
(#357) set a fuse for each field on the old layouts. Since then Depot's compact hall (DC1, #368), Woodland's new routes
(WB1, #362), Subway on two levels (SW1, #369), the bots' route variety (RV1, #358), their aim (AIM1, AIM2) and burst fire
indoors (FV1) have all merged. DC1 set Depot's fuse to 24 s and WB1 set Woodland's to 27 s, each measured before some
of the others were in.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## What the bots showed

Bot matches, 6v6, Normal, seeds 1 to 32, on main at 2851ca0 (every change above in), the same scratch runner as PB4:

| Field | Fuse | The attackers' share | Armed | Armed bombs the attackers win | Gone off |
|---|---|---|---|---|---|
| **Depot** | **24 s (kept)** | **49.8 % ±3.2** (119 of 239) | 60 % | 76 % | 4 |
| Depot | 21 s | 49.6 % ±3.2 | 60 % | 75 % | 9 |
| Woodland | 27 s (before) | 46.6 % ±3.2 (111 of 238) | 60 % | 68 % | 15 |
| **Woodland** | **25 s** | **50.0 % ±3.2** (121 of 242) | 57 % | 74 % | 31 |
| **Subway** | **22 s (kept)** | **48.5 % ±3.3** (114 of 235) | 61 % | 68 % | 0 |

At Hard (16 seeds; band 40 to 60 %), Woodland at 25 s: 54.6 % ±4.6, in the band.

## Decisions

- **Woodland 27 s to 25 s; Depot and Subway kept.** Each is now the measured value nearest 50 %. Depot reads the same
  at 21 s as at 24 s (its armed rounds are settled faster on the compact hall), so the longer 24 s stays: it gives a
  defending player more time.
- **A defending player still has time:** 25 s on Woodland is longer than PB4's 23 s, and `test_pb4_fuse` holds every
  field to the 15 m sprint margin.

## Known issues left

- None new. Plant The Bomb's row in `docs/KNOWN_ISSUES.md` carries these figures.
