# WB1 · Woodland: six routes and nearer flags (Concept B)

**Review:** PENDING

The map action redesign (MR1) found bots walked only Woodland's three authored lanes, 83 % of the floor saw a bot
in fewer than 1 round in 10, and in Attack / Defend and Plant The Bomb every fight came in the defenders' third.
The owner picked the recommended concepts on 2026-11-15 ("Go with the recommended options"): for Woodland, Concept B,
six routes and both flags about 14 m nearer the stream, same size, road clear.

## Acceptance criteria

1. Woodland keeps its size and its road stays clear (check.py TOTAL 0, test_mb2_qa); no new models or sounds.
2. Six lanes: the north edge, north middle and south middle added, the first three in their places.
3. Flag A in Fern hollow and flag B at Log stacks, the bomb sites with them; the forward defender posts on the stream
   side, the other by the pole.
4. Measured on top of RV1's route variety (PR #358), seeds 1 to 32, 6v6 Normal: Attack / Defend in its band (40 to
   65 %), Plant The Bomb near half, Woodland's fuse re-measured (PB4's rule).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | PENDING | PENDING | – |

## What changed

- `tools/woodland/layout.py`: FLAG_A (42.2, -41.4), FLAG_B (40, 42); LANE_PATHS gains `ne`, `nm`, `sm`, written in
  LANE_ORDER; the middle lane ends at Hut row; the south lane's posts are the Culvert's east head and the gap between
  B's stacks; two lights moved to the flags; areas A site and B site at the poles, the old ones renamed Fort and
  Sawmill. `world.py`: no young tree within 3 m of a flag. `build_map.py`: lanes in LANE_ORDER.
- `data/maps/woodland.json` rebuilt from them (the script's output; main's file rebuilds byte for byte).
- Tests: test_woodland_layout (six lanes, the flags), test_mb1_layouts (forward posts on the defenders' half, B's
  posts, the road check on the new pole), test_map_areas (256 boxes); QA's test_wb1_qa.
- Docs: DECISIONS (Maps and modes), KNOWN_ISSUES (Woodland's balance rows), PLAYTEST, the wiki's Maps page.

## Measured

Bots, 6v6, Normal, `tools/map_heat.gd`, main with RV1 merged in locally (its PR still open), PB4's fuse, the same seeds
before and after (Attack / Defend and Plant The Bomb seeds 1 to 32, Elimination 1 to 16):

| | Before (main + RV1) | WB1 |
|---|---|---|
| Attack / Defend attackers | 55 % ±3 (242 rounds) | 54 % ±3 (248) |
| Attack / Defend first hit (median) | 24.1 s | 19.9 s |
| Knock-outs outside the defenders' third (target west of x 25) | 12 % | 53 % |
| Plant The Bomb attackers, 23 s fuse | 46 % ±3 (239) | 53 % ±3 (235) |
| Plant The Bomb first hit | 24.3 s | 19.5 s |
| Elimination, west end | 45 % ±4.5 (120) | 47 % ±4.5 (121) |
| 2 m squares a bot stands on in ≥ 1 round in 10, Elimination / Attack / Defend | 837 / 733 | 1073 / 938 |

The first pass, with the concept's flag A spot, measured 53 % and 54 %. The mock-up's 60 % (MR1) was on the old
planner; RV1's pushed defender brings it to the band's middle, so no raise or cover change was needed.

## Decisions

- **Flag B is in the pocket of three stacks at (40, 42), not the concept's (36, 40).** That spot was on the road's
  gravel. Anywhere else on the south verge the road's S saw the pole 40 m off down the Culvert's straight; the line
  runs along the strip itself, so no piece can shut it without standing on the road. In the pocket the stack at
  (37.4, 42.4) closes the west edge of the 1.6 m ring (QA: 12 of 16 ring points standable): it is cover for both.
- **Flag A is 1.4 m off the oak.** At (41, -42) the oak's trunk stood inside the pole's ring.
- **The fuse stays 23 s** (`docs/DECISIONS.md` › Plant The Bomb's fuse): 53 % ±3 covers half.
- **No cover was added at the poles.** MB2 showed cover by a pole helps the raiser as much as the holder; the
  windthrow at A and the stacks at B already stand there, and both modes landed in band.
- **The Fort and the Sawmill keep their pieces** as the defenders' ground behind the flags; only the Box's lantern
  and the Sawmill's lamp moved. The map card (eye height from (35, -25)) was not re-rendered: it shows the Fort's
  walls, which did not move.
- An owner ruling binds later tasks: `docs/DECISIONS.md` › Woodland is Concept B.

## Known issues left

- RV1 (PR #358) was merged locally to measure; if it changes before it merges, Woodland's numbers need a re-run.
- Woodland's balance rows in `docs/KNOWN_ISSUES.md` carry the new figures.
