# RV1 · Bots vary their routes and timing each round

**Review:** 1 attempt · critic pending · qa Pass · performance Pass

The owner, 2026-11-15: bots are "too predictive and follow the same routes each time. It should feel more random
while teams still follow a general strategy/plan", and "bots don't come out far enough and I find myself running
across the map before anything happens".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | pending | – |

## Decisions

- **The team plan stays; how it is carried out varies.** Each round a team still splits, pairs or stacks over the
  map's authored lanes (`RoundPlanner`), dealt in a random order as before. On top of it, on two seeded streams of
  their own (`Seeds.variety_seed`, `Seeds.crossing_seed`, so no plan or lane draw moves):
  - **Tempo** per team per round: quick (pauses ×0.45), steady (×1) or slow (×1.4), weights 0.3 / 0.45 / 0.25. It
    scales the pauses at lane points and the stagger between lane mates.
  - **Own half first:** a pause at a lane point in the bot's own half is ×0.55. Reason: real players move up fast
    through ground their side holds and slow where the fight will be; it is the lever for "bots don't come out far
    enough".
  - **Lane shift:** each bot that walks its lane (not a defender) walks every point up to 2.5 m to one side, square to
    the way to the enemy, the same side all round; half as far, or not at all, where the spot isn't on the point's
    floor in a straight walkable line from it (`BotMovement._shifted`). Defenders keep their authored posts.
  - **Lane crossing:** setting off for its next point, a bot may (0.15 a point, at most once a round) cross to the
    nearest point within 10 m of another lane, on the same floor, no nearer home, among the points it would walk there
    (`RoundPlanner.walk_points`), preferring the lane fewest teammates walk. Never a defender, the bomb carrier or a
    bot under a squad order.
  - **Pushed defender** (Attack / Defend, Plant The Bomb): in 35 % of rounds one defender holds 35 % of the way from
    its post to the last point short of the middle. At 50 % / 50 % Woodland's attackers went to 66.5 % (24 seeds,
    band to 65 %); at 35 % / 35 % 55.9 %.
- **Lanes stay the authored three a map.** More routes through the unused rooms is a map change, proposed by the map
  redesign thread; its figures should be re-measured on top of this.
- **Two tests changed for the new variety, not their intent.** `test_bot_crossfire` pins exact lane points, so it also
  zeroes `lane_shift` (as it zeroes `lane_jitter`). `test_bot_climbs`' pit test plays up to four rounds, not two: with
  the new timing, seed 21's first two rounds ended in fights before anyone climbed.

## Verified

Headless bot matches (`tools/map_heat.gd`), Normal 6v6, against today's main at the same seeds. The route sameness
figure is the mean overlap (Jaccard) of the 4 m cells a team stood in during the first 30 s, between rounds of the
same end and role (1 = the same ground every round).

| Map, mode | First hit, main → RV1 (median) | Route sameness, main → RV1 (seeds 1-8) |
|---|---|---|
| Depot Elimination | 14.8 → 13.5 s | 0.49 → 0.46 |
| Woodland Elimination | 18.9 → 18.3 s | 0.49 → 0.43 |
| Subway Elimination | 16.2 → 15.3 s | 0.59 → 0.55 |
| Stockade Elimination | 15.3 → 14.5 s | 0.48 → 0.44 |
| Depot Attack / Defend | 22.4 → 20.4 s | 0.57 → 0.51 |
| Woodland Attack / Defend | 27.6 → 23.8 s | 0.56 → 0.48 |
| Subway Attack / Defend | 19.4 → 17.7 s | 0.63 → 0.61 |
| Stockade Attack / Defend | 21.5 → 19.8 s | 0.57 → 0.53 |

Win rates on RV1 (Normal, ± one standard error):

| Map | Elimination, end 0 (24 seeds; band 45-55 %) | Attack / Defend, attackers (16 seeds; band 40-65 %, Depot 38-67 %) |
|---|---|---|
| Depot | 54.9 % ±3.7 (near an edge) | 60.5 % ±4.3 |
| Woodland | 54.4 % ±3.7 (near an edge) | 55.9 % ±4.6 |
| Subway | 52.8 % ±3.7 | 57.4 % ±4.5 |
| Stockade | 50.8 % ±3.7 | 54.5 % ±4.5 |

Plant The Bomb on the old 30 s fuse, 24 seeds, attackers: Depot 27 → 36 %, Woodland 36 → 40 %, Stockade 36 → 39 %,
Subway 52 → 44 % (±3.7). The per-field fuses (#357) land beside this; see Known issues left.

- GUT: `test_rv1_route_variety` (8), `test_rv1_qa` (11, QA), and the bot files QA ran (`test_bot_crossfire`,
  `test_bot_climbs`, `test_bot_personality`, `test_bn1_qa`, `test_bp6_bots`, `test_bot_team_play`, `test_bot_flag`,
  `test_bots_plant`, `test_pb1_qa`, `test_two_flags`, `test_mb4_qa`) pass; the full suite in CI.

## Known issues left

- Plant The Bomb on RV1 plus the per-field fuses (#357) is re-measured once #357 is on main.
- Depot's and Woodland's Elimination end shares sit near the band's top edge (54.9 %, 54.4 %): re-measure on 32
  seeds in the next balance report.
