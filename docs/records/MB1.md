# MB1 · The three fields' layouts, reworked from their play records

**Review:** REVIEW_LINE

The owner (2026-11-12): "I want you to analyse all maps. Is the map fun to play? Is it well designed and balanced? Take
inspiration from maps in Counterstrike and Valorant. Every object and structure is designed and placed intentionally
to affect the gameplay of the map. Analyse all sightlines, choke points, heat maps, areas of cover, etc. Feel free to
make changes to the map (strict rule: no new models or sounds must be needed)." And: "if you need to adjust the size
of the map and/or cut out sections then do it. Balance and gameplay is most important. You have full freedom to design
the map as you see fit except the rule that it must not require any new models or sounds."

The replicas and attachments of the same message are another task (RP1).

## Attempts

ATTEMPTS_TABLE

## How it was measured

Three dev tools, none exported, none run by a check:

- `tools/map_heat.gd`: seeded headless bot matches through `MatchRunner`, writing where every character stood each
  second, where each knock-out's shooter and target stood and how each round ended.
  `godot --headless --path . -s res://tools/map_heat.gd -- <map id> <out.json> [seeds] [mode] [size] [first seed]`.
- `tools/map_survey.gd`: every stand point a metre apart on each floor (`FieldMeasure.stand_points`), with how many
  others see it standing and crouched, its longest clear line and each end's walk to it.
- `tools/maps/plan.py`: plan pictures, heat maps and a report by named area from both (`--file` reads another
  commit's map for a "before"); `tools/maps/los.py` is a quick 2.5D sight check for trying a layout edit.

Eight matches a mode at 6v6 and Normal are about 60 rounds, so a win share carries about ±6 points; the figures that
decided a pass were re-run to 16 matches. Bands: each end 45 to 55 % of Elimination's rounds, the attackers 40 to 65 %
of Attack / Defend's (`tools/balance.sh`).

## What the bots' planner needs of a lane

Each of these cost a pass (`game/ai/round_planner.gd`); they are written at the lanes in each layout script.

- **A lane's last two points are Attack / Defend's defender posts** (the first defender on a lane holds the one before
  last, the next the last). They belong on the site behind cover, never at a spawn's mouth or a stair's foot.
- **A squad sweeps its lane to the first point past the field's middle** (`_points_to_middle`: halfway between the
  spawn centres). A point on the middle is past it for one end only, and a deeper point for one end walks that end
  further into the open: one point either side of the middle, equally deep, none between.
- **A screen with one gap is a trap for the side that must come through it.** Bushes are walked through on a broad
  front and hide someone standing.
- **A piece in a dip hides nobody on a rise behind it:** the piece goes on the rise.
- **No lane takes a way a bot is slow on** (Subway's spiral stair: about 40 s; a lift about 10 s).

## What changed

Figures are bot matches at 6v6 and Normal, before to after; Elimination's is the west (street) end's share of decided
rounds, Attack / Defend's the attackers'.

| Field | Elimination | Attack / Defend | Knock-out range, Elimination (median; over 30 m) |
|---|---|---|---|
| Depot | 44 % ±3 (242 rounds) to 50 % ±5 (122) | 48 % ±6 to 43 % ±7 (46 % ±4 over the last three passes, 181) | 12 m, 6 % (unchanged) |
| Woodland | WOODLAND_ROW |
| Subway | 48 % ±6 to 46 % ±6 | 38 % ±6 to 55 % ±6 | 8 m, none (unchanged) |

### Depot (`tools/depot/layout.py`, `data/maps/depot.json`, 222 blocks, were 220; the bake rebuilt)

- **Found:** the lanes, links and ranges are sound (knock-outs at 12 m, 6 % over 30 m, rounds 41 s). Attack / Defend's
  defenders waited at the foot of the A stairs and the B ramp, outside the sites, and the poles stood in the open: on
  the two sites the attackers lost 188 and scored 71, and 70 defenders were caught on the stairs and the ramp.
  Elimination leaned east, 44 % for the west over 242 rounds (the first two passes, which left the middle alone,
  included).
- **A site:** a crate stack at (41.5, -27.2) between the pole and both Offices doors and one at (46.2, -23.8) between
  it and the A stairs' mouth; the corner stack at (49.2, -26), behind the pole, is gone. **B site** mirrors it:
  (42.5, 27.6) and (47.0, 24.4) in, (50, 27) out.
- **Lanes:** the north and south lanes end on the sites, one post behind the flag stack and one at the low crate by
  the stairs (ramp) mouth; the middle lane's two are behind the Garage dog-leg's stacks. Each lane has one point
  about 4.5 m either side of the middle and none between; the middle lane's pair sits 0.8 m east of even (dead even
  the west took 55 % ±4 over 195 rounds).
- **After:** on the sites 111 to 190, the median knock-out there at 10 m (16) and half inside 10 m (a fifth); 20
  defenders caught on the stairs and ramp. `tests/unit/test_baked_light.gd` counts the two blocks more.

### Woodland (`tools/woodland/layout.py`, `data/maps/woodland.json`, `tools/woodland/check.py`)

- **Found:** every lane was shot from end to end. The Ridge looked 86 m down the north lane, the Clearing 70 m over
  the Ford to Hut row, and the Long road ran 60 m with nothing on it under a hump 2.5 m over the road beyond. Of
  Elimination's knock-outs 68 % came from over 30 m (median 38 m; a round's first at 43 m), and the attackers won
  70 % of Attack / Defend, scoring 170 to 60 near the two poles from about 30 m: the Fort's west side was a low
  wall, and flag B stood open to the road.
- **North:** five hazels on the Ridge's brow and three behind (the Brow hazel; a windthrow screen with one gap gave
  the west 30 %); a fallen tree at the North bridge's west head and a cordwood stack at its east; the Fort's west
  side a full wall with a window and a doorway, crates and a tyre stack inside, a fallen tree off its south side.
- **Middle:** a cordwood stack and hazels at the Birch stand (were two low crates); two spruce thickets on the
  Ford's east bank, joined, with a hazel below and three on the crest at the head of the bank's ramp, 5 m wide; the
  Hut row crates deeper and double height, and a stack across the Back yard's mouth.
- **South:** three fallen trees across the Long road, staggered, the first on the hump's top (`tag="roadblock"`:
  `check.py` lets a piece meant to block the road stand on it); a stack on the road's east bank and one behind the
  west camp's road gate; SAWMILL_LINE
- **Lanes:** re-laid through the new pieces; the middle lane ends in the Back yard (it ended in the east camp).
  LANES_LINE
- **Passes:** WOODLAND_PASSES
- **After:** WOODLAND_AFTER

### Subway (`tools/subway/layout.py`, `data/maps/subway.json`; no block moved)

- **Found:** the closest fights of the three (median 8 m) on two of three floors: both poles stood on the south side
  (A on the south platform, B on the stair landing 11 m from it), so the north platform saw 2 % of Elimination's
  knock-outs and under 0.4 % of Attack / Defend's play time. Every attacker came down the middle stair, where the
  defenders scored 69 at its top for none lost: the attackers won 38 % and raised a flag in 5 % of rounds. One lane
  ran down the spiral stair, about 40 s for a bot, and rounds ran 80 s.
- **Flag B** stands on the north platform at (33, -7.8).
- **Lanes:** the north lane takes the lifts down and runs the north platform; the south lane takes the escalators
  and the concourse to the middle stair, its last two points (the defenders' posts) the stair's landing and foot.
  None takes the spiral stair.
- **After:** the north platform takes 17 % of Elimination's knock-outs and 41 % of Attack / Defend's (107 to 110);
  a flag goes up in 24 % of rounds; rounds run 49 s; the stair top costs the attackers 20.

## Decisions

- **No field was resized or cut,** though the owner allowed it: the first knock-out comes 15 to 24 s into a round on
  all three, and Woodland's fault was its sight lines, which cover fixed. Depot's 65 m Chrono hall line stays (owner,
  DR1).
- **Subway's blocks stay where they are** while its model threads work on them: both of its faults were the flags'
  and lanes'.
- **Woodland's lanes differ in range on purpose** (the road close, the north middling, the Clearing long), so each
  replica class has a lane.
- **Measured at Normal, 6v6, by day.** Easy, Hard, the other team sizes and Woodland's night belong to the full
  balance report of the Dev 3 final pass (`tools/balance.sh`).

## Verified

VERIFIED
