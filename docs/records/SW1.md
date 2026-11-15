# SW1 · Subway on two levels

**Review:** 2 attempts · critic CRITIC_SCORE · qa Pass · performance Pass

The owner's ask (2026-11-15, after the map redesign proposals, MR1): "make Subway map more compact. Ticket hall and
concourse should be one single level now. That means removing the escalator between the levels and also adjust the
elevator so it only goes between two levels. If you need to adjust the time the elevator takes then do it. The spiral
staircase is currently not functional so fix that so players can use it to get down to the platform. In the concourse
area remove some of the metal lockers to give longer sight lines. Rebalance the map". With it he took the proposals'
recommended Subway concept A (two more lanes, the north passage's and the west platform's).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ (lint, wiki, smoke, 9 touched unit files 127/127; the rest in CI) | 7/8 Retry | check 6: a 66.8 m line from the Street spawn into the north passage, the exception raised to fit it |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | ✓ (lint, wiki, smoke, 11 touched unit files 142/142; the rest in CI) | CRITIC_ROW | – |

## What changed

- **One level above the platforms.** The ticket hall (37 m by 20 m, `tools/subway/layout.py`) stands on the
  concourse's floor (game 8.9 m) where the booking hall and west passage were; the street level, its upper
  escalators and the escalators' model (`escalator_upper.glb`, now in `_archive/`) are gone. The gates keep seven a
  side; the ticket office, kiosk, machines, booking counter and cable drums stand in the hall.
- **Lifts of two stops** (Platforms, Ticket hall), 4 s a stop as before, now for 8 m (was 4 s for each of 4.5 m and
  8 m stops).
- **The spiral stair works.** Eight flights from beside the gates down to the south platform's west half (x -29; it
  ran ten, street level to the booking hall). Its top landing now runs to the well's walls and meets the floor round
  the hole flush: before, a 15 cm slot between landing and floor read as a drop on the bots' grid, so no bot route
  ever took the stair (players could). A body walks it down in about 7.8 s (sprinting 5.8 s); the bots' route through
  it is 24.6 m, about 5.5 s. A rail closes the top landing's west edge over the well (the owner's picture, 11:07).
- **Five lockers out:** two in each passage (the 13 m pair and the mouth pair at -4 m) and the one screening the old
  booking hall's spiral foot; each passage keeps its wall-side and inner chicane lockers. A short pier (0.6 by 0.8 m,
  3 m high) stands on each mouth's inner side, so the hall's spawn doesn't see down a passage.
- **Five lanes:** north, middle and south as before (from the new hall), plus concept A's north passage lane and a
  spiral stair lane that comes up the south platform and crosses to the north at the lower hall.
- Fixtures, dress and pictures follow the new rooms (`fixtures.py`, `station_dress.py`, `station_pictures.gd`).

## What the bots showed

Bot matches, 6v6 (`tools/balance.sh`'s runner, the field's 22 s fuse in Plant The Bomb), on the final layout with
main's bots merged in (AIM1, AIM2, RV1; head 44fd9fe): Normal on seeds 1 to 32 (band 45 to 55 % for Elimination's
ends, 40 to 65 % for the attackers), Hard on 16 (band 40 to 60 %).

| Figure | Before (AUD1 16 seeds; PB4 32) | SW1 Normal | SW1 Hard |
|---|---|---|---|
| Elimination: the west end's share | 50.8 % ±4.5 | 48.5 % ±3.2 (115 of 237) | 54.5 % ±4.5 (66 of 121) |
| Elimination: Alpha's share | 49.2 % | 51.1 % ±3.2 | 52.9 % ±4.5 |
| Elimination: first hit, median | – | 14.8 s at 9.3 m | 16.9 s at 10.0 m |
| Attack / Defend: the attackers' share | 57.8 % ±4.4 | 57.3 % ±3.2 (137 of 239) | 53.0 % ±4.6 (62 of 117) |
| Plant The Bomb: the attackers' share | 54.9 % ±3.1 (PB4, 22 s) | 49.3 % ±3.3 (111 of 225) | 52.1 % ±4.5 (63 of 121) |
| Plant The Bomb: armed / armed gone off | 82 % / 8 of 239 rounds (PB4) | 72 % / 10 of 161 | 66 % / 0 of 80 |
| Rounds that run out the clock | 0 | 0 in every mode | 0 in every mode |

Every figure is in its band and none near an edge, so nothing was tuned: the fuse stays 22 s. On the way, on the
pre-merge bots: the first layout read Normal 49.8 / 58.1 / 56.6 % (west end, A/D, PTB) and Hard's west end 58.8 %;
with the mouth piers and the concourse piers run out, Normal's west end 55.9 % (outside, within noise); with the
concourse piers taken back, 49.4 %.

The map heat tool (`tools/map_heat.gd`, 8 seeds a mode, the MR1 report's measure) before and after:

| Measure | Before (main 7c09060) | SW1 |
|---|---|---|
| Elimination: Street end's share | 52 % (33 of 63) | 44 % (25 of 57) |
| Elimination: rounds with a fight in under a tenth of the floor | 60 % | 48 % |
| Elimination: first hit (median) | 16 s | 16 s |
| Attack / Defend: attackers' share | 64 % | 59 % (35 of 59) |
| Attack / Defend: hits outside the defenders' third | – | 44 % |
| Plant The Bomb: attackers' share | 52 % (30 s fuse) | 45 % (25 of 56, 22 s fuse) |
| Spawn to spawn walk | 147 m | 135 m |
| Upper level's longest sight line (the field checks') | 28 m | 57 m (66.8 m before the mouth piers) |

## Decisions

- **The ticket hall and concourse are one level (owner).** `docs/DECISIONS.md` › Subway is a station on two levels.
- **The lift keeps 4 s a stop** (`LiftConfig.floor_time`): the owner allowed a change, but 4 s for the 8 m drop
  is a car at 2 m/s, a lift's usual speed, and the spiral stair at 6 to 8 s stays the slower, quieter way down.
- **The hall keeps its 20 m width (z -10 to 10)** and grows east to the concourse (37 m long), so SM3's seven gates a
  side, 12 lanes and 24 paddles stand as they were, their models and tests unchanged.
- **The spiral stair lands on the south platform**, in its west half, where the old booking
  hall's foot can't go now that the hall is on the concourse's floor: the owner asked for it "to get down to the
  platform".
- **Which lockers went:** the ones that cut the passages' long axis (13 m and the mouths); the wall-side chicane lockers
  stay so each passage still has cover. With the mouth lockers gone the field checks found a 66.8 m line from the hall's
  west end (the Street team's spawn) slipping past a mouth's corner into the north passage (critic, attempt 1). A short
  pier on each mouth's inner side (0.6 by 0.8 m, the mouth 2.2 m wide) closes it (running the concourse's piers out to
  the passages' line as well changed no line and was taken back): the longest upper line is 57 m, the hall's west end to
  a passage's mouth, and from the spawn spots 3 of about 1,100 passage points are seen, all at a mouth. The Subway
  exception stays 60 m.
- **Two lanes added, the spiral's and the north passage's (MR1 concept A).** DECISIONS' lane rule (no lane on a way a
  bot is slow on) now lets the spiral stair have one: it is a 6 s walk.
- **The cable drums and booking counter stay** in the new hall: SM4's and SM3's models and tests need them, and they
  give the hall's north wall cover.
- **The plan's storey names** (`tools/maps/plan.py`) name two storeys for Subway.

## Known issues left

- The balance row in `docs/KNOWN_ISSUES.md` (Maps, Subway) carries the new figures; Easy was not re-measured, and the
  upper level's 57 m line joins the platform's 58 m under the field checks' Subway exception (`FieldStandard`, 60 m).
