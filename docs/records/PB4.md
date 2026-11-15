# PB4 · Plant The Bomb: a fuse for each field

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

The owner's ask (2026-11-15): "Balance plant the bomb attackers win rate so it's more fair." The Dev 3 audit
(AUDIT_REPORT.md 10.4) had the attackers at 37.9 % on Depot and 37.2 % on Woodland, under the 40 to 65 % band, with the
fuse 30 s and the defuse 6 s on every field.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ (lint, wiki, touched unit files; the rest in CI) | 7/8 Accept | – (check 8: the record's Hard placeholder and seed count, a decision line over 120 columns; fixed) |

## What the bots showed

Bot matches, 6v6, Normal, 32 seeds a field, the same seeds every run (main at a8e9863; a scratch runner over
MatchRunner, as `tools/balance.sh` plays Plant The Bomb, with the fuse set per run):

| Field | Fuse | The attackers' share | Armed | Armed bombs the attackers win | Gone off |
|---|---|---|---|---|---|
| Depot | 30 s (before) | 37.9 % ±3.1 (94 of 248) | 70 % | 53 % | 1 |
| Depot | 20 s | 41.7 % ±3.2 | 70 % | 59 % | 12 |
| Depot | 17 s | 46.0 % ±3.2 | 66 % | 68 % | 30 |
| **Depot** | **16 s** | **51.5 % ±3.2** (123 of 239) | 67 % | 76 % | 46 |
| Depot | 15 s | 56.9 % ±3.2 | 68 % | 83 % | 62 |
| Woodland | 30 s (before) | 37.2 % ±3.1 (90 of 242) | 69 % | 49 % | 2 |
| **Woodland** | **23 s** | **52.8 % ±3.3** (122 of 231) | 73 % | 65 % | 26 |
| Subway | 30 s (before) | 45.9 % ±3.3 (106 of 231) | 83 % | 53 % | 0 |
| Subway | 26 s | 45.9 % ±3.3 | 82 % | 54 % | 1 |
| **Subway** | **22 s** | **49.0 % ±3.2** (117 of 239) | 82 % | 57 % | 8 |
| Subway | 20 s | 48.9 % ±3.3 | 82 % | 57 % | 11 |
| Stockade | 30 s (before) | 37.1 % ±3.2 (86 of 232) | 49 % | 59 % | 1 |
| **Stockade** | **20 s** | **40.3 % ±3.2** (94 of 233) | 48 % | 67 % | 7 |
| Stockade | 17 s | 40.4 % ±3.2 | 46 % | 72 % | 16 |

At Hard (16 seeds; band 40 to 60 %) with the new fuses: Depot 42.1 % ±4.5 (armed in 50 % of rounds), Woodland 56.4 %
±4.6, Subway 58.3 % ±4.4 (the same 58.3 % at 30 s: the fuse doesn't move Subway at Hard). All three are in the band,
Depot and Subway near its two ends.

Why the fuse: with 30 s an armed bomb was settled by the fight long before the fuse mattered. A defuse came a median 16
s after the plant on Depot, 21 s on Woodland, 13.5 s on Subway and 15 s on Stockade, nearly always once the last
attacker was out (PB1's finding). A fuse near that time makes the defenders win the fight *and* reach the bomb in time,
so the attackers holding the site are worth something. The attackers who never arm the bomb almost never win (1 of 74
such rounds on Depot, 7 of 74 on Woodland, 4 of 40 on Subway), so the fuse moves only the armed rounds, and the share
of rounds armed stays where it was on every field.

## Decisions

- **The fuse is a field's (data/maps.md `Fuse (s)`), as Woodland's flag raise is (MB3); the game's stays 30 s for a
  field with none.** The fields differ by more than one fuse can cover: Depot's sites lie near the defenders' start,
  Woodland's defenders walk far, Subway was already near half. A field whose layout changes (the map redesign thread
  measured a compact Depot concept at about 49 % with today's 30 s) is re-tuned by one cell.
- **The defuse stays 6 s, the plant 3.5 s:** the owner's recordings (AU11, "the kit at work" and "keying the code") are
  cut to those lengths and `test_au11_qa` holds them to the tuning; a longer defuse would also give a defending
  player less of the fuse to reach the bomb.
- **Depot 16 s, Woodland 23 s, Subway 22 s, Stockade 20 s.** Each is the measured value nearest 50 %, rounded to a
  whole second. Subway changes little between 26 and 20 s (its defuses come quickly), so 22 s, the longer of the two
  that read 49 %, gives a player more time.
- **A defending player still has time.** Within BotConfig.plant_player_claim (15 m) of the bomb no bot defuses until the
  fuse leaves the defuse plus plant_takeover_margin (4 s): on Depot's 16 s that is 6 s to come and start, against a
  2.4 s sprint from 15 m (`test_pb4_fuse` holds every field to it).
- **A defender at the far site has a race, not a sure thing.** On Depot the sites are 53 m apart in a straight line:
  a sprint there takes about 9 to 10 s of the 16 s, leaving the 6 s defuse with nothing to spare unless they set off
  while the bomb is being keyed in (3.5 s, heard within the bots' hearing of it). That is the same bargain as a
  rotate in any bomb game, and it is the first play check (docs/PLAYTEST.md › PB4). Woodland's sites are 77 m apart:
  about 13 s of its 23 s.
- **What moved:** the share of rounds armed barely changed (Depot 70 % to 67 %); the attackers now win more of the
  rounds they arm (Depot 53 % to 76 %, with 46 bombs going off in 239 rounds where 1 did). The balance comes from a
  plant being harder to undo, not from reaching the site more often: the map redesign work is where reaching it
  changes.
- **The Match page says the field's fuse** under the rules whenever Plant The Bomb is picked ("An armed bomb goes off
  after 16 s on this field."): every field now has its own, so the note doesn't name "the others". The wiki's Maps
  table gains a Bomb fuse column.
- **Stockade (dev only) stays near 40 %.** Its attackers arm the bomb in only 48 % of rounds; a shorter fuse can't win
  rounds where nothing is armed (17 s read the same as 20 s). That is a layout matter, left to the map redesign
  work.

## Known issues left

- Stockade's attackers at about 40 % (in band at its bottom): they lose before the plant.
