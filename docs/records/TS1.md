# TS1 · 6v6 on every field, 5v5 to 8v8 under Custom

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | ✓ (local) | CRITIC | – |

## Goal

The owner (2026-11-01): "6v6 as default with option to go to 7v7 or 8v8 on all maps? 5v5 could remain an option?",
then "Check all maps and rebalance them if needed. The game should still feel fun and fair no matter the option
5v5, 6v6, 7v7, 8v8. Player size should mostly just affect the pace of the game", and to go with the defaults and say
which were taken.

## Acceptance

1. Every field (Depot, Woodland, The Street) offers 5v5 to 8v8 with 6v6 its standard (`data/maps.md`); Custom's Team
   size row offers them; Skirmish plays 6v6.
2. Each end of each field has eight spawns and eight dead-zone spots on walkable floor, out of sight of the field; 6v6
   keeps the middle six of each line.
3. An 8v8 builds and plays on every field: nobody stuck, held up or left at spawn (the guards at 8v8).
4. The bot load's frame cost at 8v8 is measured against Low's 60 fps; the fairness and pace of every size on every
   field is measured, and a field that tips is rebalanced or reported.

## Approach

- `data/maps.md`: 5, 6, 8 on all three fields. `CustomRules.TEAM_SIZES` 1 to 8 (en.po: the 7v7 and 8v8 blurbs).
- Spawns and dead zones from the build scripts (`tools/*/layout.py`, `build_map.py`), eight a side: Depot's lines 1 m
  apart between the inner screens (0.75 m clear of the nearer one), Woodland's and The Street's 2 m apart on the old
  lines' middles; dead zones two columns of four. Only `spawns` and `deadZones` changed in the map files.
- The Tab scoreboard is held at the share of its size that fits under `BOARD_TOP` (`Hud._fit_board`): an 8v8's
  sixteen rows ran 3 px off a 1080p screen at HUD size 100 % with the Pro tip, and far off at 150 % (QA).
- Measuring: `tools/team_bench.gd` (a whole session stepped by hand, tick and frame timed, dev only);
  `tools/balance.sh SIZE=n` (the balance report at any size, The Street added, and each mode's median round length).

## Measured

**Frame cost** (`tools/team_bench.gd`, cloud CPU, headless, no GPU, 120 s of match time a run, tick and the frame's
views together, ms: mean / 99th percentile): Depot 2.6 / 5.7 at 5v5, 3.3 / 6.5 at 6v6, 4.5 / 9.8 at 8v8; Woodland 2.6
/ 7.4, 4.1 / 8.6, 6.3 / 14.1; The Street 3.0 / 6.1, 3.4 / 7.5, 4.0 / 10.5. Woodland at 8v8 is the worst: on average
about 10 ms of Low's 16.7 ms is left to draw, little at its slowest 1 % (performance agent: 8 to 73 of 2400 frames
over 16.7 ms on a busier machine). The draw is the owner's to measure (PLAYTEST › Team sizes).

**Guards at 8v8** (`MatchGuard`, 8 seeds at Normal, both modes, every field): all pass. Nobody stayed home or was
held up past the limit on Depot (its staging chicanes and tunnels don't choke).

**Fairness and pace** (balance report, 16 seeds a size at Normal, about 120 rounds each; Elimination's end shares and
Attack / Defend's attackers' share, band 45 to 55 % and 40 to 65 %; the median round length; hits a minute from the
hit counts):

BALANCE_TABLE

**Pace.** Rounds last about as long at every size (Depot 44 s, Woodland 51 to 55 s, The Street 56 to 64 s in
Elimination); what grows is the action: hits a minute rise about 65 % from 5v5 to 8v8 (Depot 10.5 to 17.3, Woodland
9.1 to 13.8, The Street 8.2 to 13.7). So 5v5 plays slower and more careful and 8v8 faster and busier, as asked.

## Decisions

- **Every size stays on every field (default taken).** Depot and Woodland are fair at every size. The Street's
  Elimination leans to the north end at every size, most at 8v8 (64 % on three runs); teams stay even because the
  ends swap at half time, and its Attack / Defend is in band. Two fixes were tried and measured, neither kept: a van
  parked at the back lane's mouth (8v8 69 %, 6v6 65 %) and the south team's anchors holding nearer the middle on the
  Path and the back lane (8v8 64 %). The lean is The Street's own (it reaches the Yard, the car park and the Green
  corner sooner), so it goes to KNOWN_ISSUES for a Street rebalance rather than dropping 8v8 there.
- Spawn spacing and dead-zone layout: Claude's defaults (above), each 6v6 still standing on the middle six.
- The guards and the balance report play the standard 6v6; `SIZE=n` plays another.
- Follow me's guard no longer judges a follower while a flash dazzles it (it ducks blind where it stands, as SF1 has
  it) and gives it the usual rejoin time after: with the new spawn lines Depot's seed 3 put the leader's follower in a
  flash for 1.4 s and the leader 10 m on. Not a following fault, so the guard, not the bots, changed.

## Verified

- `tools/check.sh` gates locally: gdlint, changelog notes, wiki, unit tests (four parts), smoke test, notices.
- The tests: shipped sizes 5, 6, 8 on all three; 9v9 refused; an 8v8 on Woodland gives everyone a spawn and a dead-zone
  spot of their own; at 8v8 on Woodland no bot waits a second for a route; the Tab board fits an 8v8 at HUD size 150 %
  (fails without `_fit_board`).

## Outstanding

- The Street's Elimination north-end lean (KNOWN_ISSUES).
- The draw at 8v8 on a GPU, and how each size feels: the owner (PLAYTEST › Team sizes).
- CI's guard jobs now play 6v6: about a quarter longer (the longest about 24 of its 30 minutes, performance agent).
