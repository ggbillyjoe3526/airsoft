# WB1 · Woodland: six routes and nearer flags (Concept B)

**Review:** PENDING

The map action redesign (MR1) found bots walked only Woodland's three authored lanes, 83 % of the floor saw a bot
in fewer than 1 round in 10, and in Attack / Defend and Plant The Bomb every fight came in the defenders' third.
The owner picked the recommended concepts on 2026-11-15 ("Go with the recommended options"): for Woodland, Concept B,
six routes and both flags about 14 m nearer the stream, same size, road clear.

## Acceptance criteria

1. Woodland keeps its size and its road stays clear (check.py TOTAL 0, test_mb2_qa); no new models or sounds.
2. Six lanes: the north edge, north middle and south middle added, the first three in their places.
3. Flag A in Fern hollow and flag B at Log stacks, the bomb sites and the pole's cover with them; the forward defender
   posts on the stream side, the other on the flag's site (by the pole, or where the concept put it on the way in).
4. Measured on main, seeds 1 to 32, 6v6 Normal, and checked with RV1's route variety (PR #358, not merged yet):
   Attack / Defend in its band (40 to 65 %), Plant The Bomb near half, Woodland's fuse re-measured (PB4's rule).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | ✓ | Retry 7/8 | site cover didn't move; two home posts 10-14 m off their poles; measured only with RV1 |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | PENDING | PENDING | – |

## What changed

- `tools/woodland/layout.py`: FLAG_A (42.2, -41.4), FLAG_B (40, 42); LANE_PATHS gains `ne`, `nm`, `sm`, written in
  LANE_ORDER; the middle lane ends at Hut row; the south lane's posts are the Culvert's east head and the gap between
  B's stacks; two lights moved to the flags; areas A site and B site at the poles, the old ones renamed Fort and
  Sawmill; the pole's crouch crate moved from the Fort to flag A's west side. `world.py`: no young tree within 3 m of
  a flag. `build_map.py`: lanes in LANE_ORDER. `data/maps.md`: Woodland's fuse 27 s (23).
- `data/maps/woodland.json` rebuilt from them (the script's output; main's file rebuilds byte for byte).
- Tests: test_woodland_layout (six lanes, the flags), test_mb1_layouts (forward posts on the defenders' half, B's
  posts, the road check on the new pole, every last post within 15 m of a pole), test_map_areas (256 boxes); QA's test_wb1_qa.
- Docs: DECISIONS (Maps and modes), KNOWN_ISSUES (Woodland's balance rows), PLAYTEST, the wiki's Maps page.

## Measured

Bots, 6v6, Normal, `tools/map_heat.gd`, seeds 1 to 32 (Elimination 1 to 16), PB4's fuses. On main is what merges;
"with RV1" had PR #358 merged in locally.

| | Before | WB1 |
|---|---|---|
| Attack / Defend attackers, on main | 60 % (MR1's mock-up, 8 seeds) | 55 % ±3 (236 rounds) |
| Attack / Defend attackers, with RV1 | 55 % ±3 (242) | 54 % ±3 (248) |
| Attack / Defend first hit (median), on main / with RV1 | 28 s (MR1) / 24.1 s | 20.8 s / 19.9 s |
| Knock-outs outside the defenders' third (target west of x 25), on main / with RV1 | 9 % (MR1) / 12 % | 50 % / 53 % |
| Plant The Bomb attackers, on main | – | 59 % at 23 s, 56 % at 26 s, **51 % ±3 at 27 s** (241), 50 % at 30 s |
| Plant The Bomb attackers, with RV1, 23 s | 46 % ±3 (239) | 53 % ±3 (235) |
| Elimination, west end, with RV1 | 45 % ±4.5 (120) | 47 % ±4.5 (121) |
| 2 m squares a bot stands on in ≥ 1 round in 10, Elimination / Attack / Defend, with RV1 | 837 / 733 | 1073 / 938 |

Attempt 2's variants, on main, Attack / Defend: the two middle routes' last posts by their poles (3 m off) 64 % ±3
(249), the same without the moved crate 61 % ±3 (240), the concept's posts with the crate 55 % ±3. The crate is
within noise; the posts carry the difference. The 26 and 30 s fuses ran with the posts by the poles. RV1 moves both
modes by 1 to 4 points down; its own follow-up re-measures every map once the reworks land (owner, 2026-11-15).

## Decisions

- **Flag B is in the pocket of three stacks at (40, 42), not the concept's (36, 40).** That spot was on the road's
  gravel. Anywhere else on the south verge the road's S saw the pole 40 m off down the Culvert's straight; the line
  runs along the strip itself, so no piece can shut it without standing on the road. In the pocket the stack at
  (37.4, 42.4) closes the west edge of the 1.6 m ring (QA: 12 of 16 ring points standable): it is cover for both.
- **Flag A is 1.4 m off the oak.** At (41, -42) the oak's trunk stood inside the pole's ring.
- **The site cover moved with the flags.** The pole's own piece, MB1's crouch crate (2.4 m from the old pole, on the
  side the attack came in by), stands 2.4 m west of flag A, the stream side. B's pocket stacks stand where the
  Sawmill's cover stood from the old pole (2.6, 4.2 and 4.7 m off for 2.9, 4.3 and 6.0 m), so nothing more moved
  there: the yard crates and the MB1 stack still shut the road's lines into the Sawmill. More cover by a pole helps
  the raiser as much as the holder (MB2).
- **The north middle and south middle routes end at the concept's posts,** north of Hut row then the Hollow way's
  head (14 m short of A), and the Knoll's east side then north of Log stacks (10 m short of B), on the way the attack
  comes. Brought to 3 m from their poles, Attack / Defend's attackers won 64 % ±3, the band's edge, against 55 % ±3.
  The other lanes' last posts are by their poles (2 to 4 m); test_mb1_layouts holds every Woodland last post within
  15 m of a pole.
- **The fuse is 27 s** (was 23 s; `docs/DECISIONS.md` › Plant The Bomb's fuse): 51 % ±3 on main.
- **The Fort and the Sawmill keep their other pieces** as the defenders' ground behind the flags; only the Box's
  lantern and the Sawmill's lamp moved. The map card (eye height from (35, -25)) was not re-rendered: it shows the
  Fort's walls, which did not move.
- The owner's ruling and WB1's own choices, marked apart: `docs/DECISIONS.md` › Woodland is Concept B.

## Known issues left

- RV1 (PR #358) isn't merged; WB1 is measured on main and with it. Its follow-up re-measures every map after the
  reworks (owner's ask).
- Woodland's balance rows in `docs/KNOWN_ISSUES.md` carry the new figures.
