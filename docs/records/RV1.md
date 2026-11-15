# RV1 · Bots vary their routes and timing each round

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

The owner, 2026-11-15: bots are "too predictive and follow the same routes each time. It should feel more random
while teams still follow a general strategy/plan", and "bots don't come out far enough and I find myself running
across the map before anything happens".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | 6: the route change too small to feel (crossings rare, none on Woodland) |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The team plan stays; how it is carried out varies.** Each round a team still splits, pairs or stacks over the
  map's authored lanes (`RoundPlanner`), dealt in a random order as before. On top of it, on two seeded streams of
  their own (`Seeds.variety_seed`, `Seeds.crossing_seed`, so no plan or lane draw moves):
  - **Tempo** per team per round: quick (pauses ×0.45), steady (×1) or slow (×1.4), weights 0.3 / 0.45 / 0.25. It
    scales the pauses at lane points and the stagger between lane mates.
  - **Own half first:** a pause at a lane point in the bot's own half is ×0.55. Reason: real players move up fast
    through ground their side holds and slow where the fight will be; it is the lever for "bots don't come out far
    enough".
  - **Lane shift:** each bot that walks its lane (not a defender, nor an Elimination anchor: both hold authored
    posts) walks every point up to 2.5 m to one side, square to the way to the enemy, the same side all round; less
    far (`lane_shift_tries`, `lane_shift_fallback`), or not at all, where the spot isn't on the point's floor in a
    straight walkable line from it (`BotMovement._shifted`).
  - **Lane crossing:** setting off for its next point, a bot may (0.1 a point, at most once a round) cut across to
    another lane: the nearest point within 45 m and 1.5 m of height (the same storey; a slope's rise is fine), no
    nearer home, among the points it would walk there (`RoundPlanner.walk_points`), each teammate on that lane
    counting 8 m further off. Never a defender, the bomb carrier, a bot under a squad order, or a team that stacks
    this round (the critic's second review: crossings scattered a stack over every lane, so the plan no longer read as
    one; split and paired teams still cross). Reason: the critic's
    first review (7/8) found the route change too small to feel; at the first 10 m reach Woodland, whose lanes run
    about 40 m apart, never crossed at all. Now every map crosses (bots a round: Elimination 4.3 to 6.9 of 12,
    Attack / Defend 2.3 to 3.5, Plant The Bomb 1.8 to 2.9).
  - **Pushed defender** (Attack / Defend, Plant The Bomb): in 35 % of rounds one defender holds 35 % of the way from
    its post to the last point short of the middle. At 50 % / 50 % Woodland's attackers went to 66.5 % (24 seeds,
    band to 65 %); at 35 % / 35 % 53 to 56 %.
- **Lanes stay the authored three a map.** More routes through the unused rooms is a map change (the map rework
  threads); this is re-measured on top of them (owner, 2026-11-15: rebalance after the map reworks).
- **Tests changed for the new variety, not their intent.** `test_bot_crossfire` pins exact lane points, so it also
  zeroes `lane_shift` (as it zeroes `lane_jitter`); `test_bots`' crouched-teammate case (HV1) was found on the
  authored lanes, so it zeroes the bots' shift. `test_bot_climbs`' pit test and `test_bot_vaults`' low-wall test play
  up to four rounds, not two: with the new timing their seed's first two rounds could end in fights before anyone
  reached the ledge. `test_fg2_qa` allows the one pushed defender past point 2. The match runner's held-up guard counts a bot waiting
  on a landing for its route's lift as waiting on purpose (it gives up after `lift_patience`): Subway seed 11 had one
  wait about 10 s for a car parked at the far landing, which read as held up. Its Follow me guard no
  longer judges a follower while it stands still to throw a smoke or flash of its own (`BotBombs.busy`), as it already
  left out a dazzled one: on Depot seed 3 one fell 8.4 m behind after a throw (the bar is 8 m).

## Verified

Headless bot matches (`tools/map_heat.gd`, a scratch copy counting crossings), Normal 6v6. Main: seeds 1 to 8 (24
for Woodland Attack / Defend); RV1: seeds 1 to 24, on main with the per-field Plant The Bomb fuses (#357). Route
sameness is the mean overlap (Jaccard) of the 4 m cells a team stood in during a round's first 30 s, between rounds of
the same end and role: 1 is the same ground every round.

| Map, mode | Route sameness, main → RV1 | First hit (median), main → RV1 | Win rate on RV1 (± 1 SE) | Band |
|---|---|---|---|---|
| Depot Elimination | 0.49 → 0.42 | 14.8 → 14.6 s | end 0 53.2 % ±3.7 (main 50.0 %) | 45-55 % |
| Woodland Elimination | 0.49 → 0.39 | 18.9 → 18.8 s | end 0 51.9 % ±3.7 (main 48.1 %) | 45-55 % |
| Subway Elimination | 0.59 → 0.56 | 16.2 → 15.3 s | end 0 56.1 % ±3.7 (main 52.4 %), outside within noise | 45-55 % |
| Stockade Elimination | 0.48 → 0.41 | 15.3 → 15.1 s | end 0 50.0 % ±3.7 (main 47.4 %) | 45-55 % |
| Depot Attack / Defend | 0.57 → 0.49 | 22.4 → 20.5 s | attackers 56.0 % ±3.7 (main 46.7 %) | 38-67 % |
| Woodland Attack / Defend | 0.56 → 0.48 | 26.5 → 25.9 s | attackers 53.0 % ±3.7 (main 54.7 %) | 40-65 % |
| Subway Attack / Defend | 0.63 → 0.60 | 19.4 → 17.9 s | attackers 61.2 % ±3.7 (main 63.9 %) | 40-65 % |
| Stockade Attack / Defend | 0.57 → 0.50 | 21.5 → 20.8 s | attackers 50.6 % ±3.7 (main 56.2 %) | 40-65 % |
| Depot Plant The Bomb | 0.56 → 0.50 | 22.3 → 20.3 s | attackers 59.8 % ±3.6 (main with #357 51.6 %) | 40-65 % |
| Woodland Plant The Bomb | 0.57 → 0.48 | 26.7 → 26.0 s | attackers 50.8 % ±3.7 (main with #357 54.8 %) | 40-65 % |
| Subway Plant The Bomb | 0.64 → 0.62 | 20.9 → 20.4 s | attackers 54.7 % ±3.7 (main with #357 54.9 %) | 40-65 % |
| Stockade Plant The Bomb | 0.54 → 0.49 | 22.2 → 22.3 s | attackers 42.8 % ±3.8 (main with #357 40.3 %) | 40-65 % |

- **After the stack rule (attempt 2's last change), 8 to 24 seeds:** Elimination end 0 Depot 52.3 % ±6.2, Woodland
  43.5 % ±3.7 (24 seeds; outside within noise, main 47.6 % ±3.2 over 32 seeds in KNOWN_ISSUES), Subway 50.3 % ±3.6
  (24 seeds), Stockade 49.2 % ±6.5; Attack / Defend attackers Depot 50.9 %, Woodland 56.7 %, Subway 56.9 %, Stockade
  46.7 % (±6.5). Crossings a round fall a little (Elimination 3.7 to 5.7). Stockade was removed from the game on main
  (SK2, #359) while this ran, and AIM1 (#360) changed the bots' aim after these figures; both are in the re-measure
  after the map reworks.
- **What it does for "fights start late":** Attack / Defend and Plant The Bomb meet 1 to 2 s sooner; Elimination
  doesn't move (about 15 s, the walk to the middle at a run plus a beat). The first version, with fewer crossings,
  had Elimination 0.6 to 1.3 s sooner; the cuts across lanes take that back. Coming out further on the player's side
  is the map reworks' lever (smaller fields, more routes).
- GUT: `test_rv1_route_variety` (9), `test_rv1_qa` (11, QA), the bot files QA ran and the four adjusted ones pass;
  CI's seven unit parts, smoke test and every match guard are green on 63d942b.

## Known issues left

- A cross only checks that the point it makes for is no nearer home, not the route there: on Depot or Subway, with
  45 m of reach, a route round a wall could double back for a stretch (the critic's advisory; none seen in the runs).

- Woodland Elimination's west end at 43.5 % ±3.7 after the stack rule (24 seeds), outside within noise; Subway's
  street end swung from 56.1 % to 50.3 % between two 24-seed runs, so these figures are noisy. Re-measured on 32
  seeds on the reworked maps (this thread re-measures every map once the reworks merge).
