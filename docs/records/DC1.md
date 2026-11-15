# DC1 · Depot's compact hall

**Review:** 1 attempt · critic pending · qa Pass · performance Pass

The owner's pick (2026-11-15, "Go with the recommended options") of the map redesign's concept B for Depot
(report https://claude.ai/artifact/MJvwgMNiyip7EaH5Mxa6Sz; mock-ups `/mnt/project-files/maps-redesign/prototypes/`).
He had said much of the map went unused: bots walked only its three lanes, and in Attack / Defend and Plant The Bomb
the defenders stood within 8 m of their spawn, so the attackers walked 95 m before anything happened.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ (lint, wiki, smoke, all 209 Depot test files; the rest in CI) | pending | – |

## What changed

- **The west 10 m is closed:** the hall is 98 x 72 m (x -44 to 54). Staging, its North and South stairs and its
  two-screen chicanes are the concept's, moved 10 m east onto the old Mid exit; the room opens onto Upper mid through
  an 8 m mouth behind its crate rack, a plywood wall closing the rest of its east side. The Side alley and the Mid exit
  are gone (the stairs are the Yard's and the Pens' ways in); the Yard and the Pens lost their west 10 m.
- **Flags and bomb sites 8 m in:** A (36.5, -26.5), B (37, 27.5), each site's middle a metre towards the hall.
- **The chrono hut and its overtime flag 4.5 m east,** onto the new middle (end 0 walks 54.7 m to the flag, end 1
  53.9 m; 49.8 and 58.3 before it moved, which failed FieldChecks' 15 %).
- **Five lanes:** each side's corridor, each side's rooms (the Shoot House's north row, the Lounge and the Offices
  rooms; the South stairs, the Pens, the Huts, the Box yard's south and between the containers) and the middle. Each
  keeps MB1's one point either side of the middle, 4.4 to 4.6 m deep for both ends. Defender posts: the Offices door,
  Lower mid (29, -2.2, behind its low crate), the end of the Containers (26.5, 24.5, behind theirs) and the sites' doors.
- **Plant The Bomb's fuse on Depot 24 s** (16 s before).
- The light rebaked, the Match picture re-rendered from (8, 0) (the old spot is at the moved hut), the wiki's Depot
  section, nine tests that named old spots or counts, QA's `test_dc1_qa.gd`.

## What the bots showed

Normal, 6v6, seeds 1 to 32, `tests/balance/balance_run.gd`, on main at 7c09060 (before AIM1, AIM2 and the bot route
variety RV1, which change bots and so these figures):

| Figure | Before (main) | After (DC1) |
|---|---|---|
| Elimination, the west end's share | 51.6 % ±3.2 | 47.4 % ±3.2 |
| Elimination, median first hit | 14.7 s | 13.1 s |
| Elimination, median range of the first hit | 14.5 m | 18.8 m |
| Attack / Defend, the attackers' share | 54.1 % ±3.3 | 53.0 % ±3.2 |
| Attack / Defend, rounds won by raising the flag | 43.2 % | 31.3 % |
| Plant The Bomb, the attackers' share (16 s fuse) | 51.6 % ±3.2 | 64.3 % ±3.1 |

Plant The Bomb on the compact hall by fuse: 16 s 64.3 % ±3.1, 20 s 55.6 % ±3.2, 22 s 53.1 %, 23 s 51.4 %, 24 s 48.4 % ±3.2,
28 s 47.6 % ±3.2
(the bomb armed in 63 to 66 % of rounds at every fuse; at 24 s only 3 % of armed bombs go off, 28 % are made safe).

The layout timing (`test_depot_hall`, at a run): the Chrono hall's overtime flag 0.8 s apart; the Lounge 3.8 s
sooner for the west, the Box yard 2.7 s sooner for the east (each timed from the field's middle as the concept was).

On RV1's branch with DC1 (bot route variety, before it merged): Elimination's west share 51.5 %, median first hit
12.6 s; Attack / Defend's attackers 52.1 %.

## Decisions

- **The west wall at x -44, not the mock-up's -41** (`docs/DECISIONS.md` › Depot is the compact hall). The mock-up's
  spawn line stood in the open Mid exit, seen from Upper mid; a spawn room with the concept's chicanes needs 10 m. The
  mock-up's cut through the racks south of the spawn is the South stairs, in the same place.
- **The hut moved, not the spawns:** the overtime flag must be as far from both ends (FieldChecks), and the side rooms
  are timed from the field's middle, which the shorter west half moved 4.5 m east; the test now computes the middle
  from the spawns.
- **The Huts' gap into the Box yard 1.5 m south** (z 24 to 28): with the west 10 m nearer, it reached the Lounge 3.7 s
  ahead but the Box yard only 2.2 s behind; the gap evens the two leads (1.1 s apart, under the 1.5 s the hall test
  holds). Moving the spawn back or narrowing its mouth moved nothing (both shift the middle too).
- **Two defender posts behind low crates** (Lower mid, the end of the Containers): a Hard defender takes cover beside
  its post only behind low cover (`test_fg2b_qa`); the mock-up's posts stood in the open.
- **The flag stacks stay** (MB1): the poles now stand at the hall's end of the sites, beside the crates already there;
  Attack / Defend measured 53 % with them as they are.
- **The east strip was not trimmed** (the concept's optional 6 m): it would rebuild the Loading bay and its chicanes,
  and the figures are in band without it.
- **Fuse 24 s, not 23:** 23 s measured nearest half (51.4 %), but Woodland's is 23 and a Match page test needs the
  fields' fuses to differ to prove a map switch rewrites the note; 24 s (48.4 %) is as near half and in band.

## Known issues left

- The figures were measured before AIM1, AIM2 and RV1 (bot route variety, still open): the Plant The Bomb fuses are
  measured again once the map reworks and RV1 are in (`docs/KNOWN_ISSUES.md` › Modes, PB4's follow-up).
- How the new west end plays, the re-rendered Match picture and the minimap in a window are play checks
  (`docs/PLAYTEST.md` › Depot's compact hall; the owner's checklist).
