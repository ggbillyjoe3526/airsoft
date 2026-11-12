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
decided a pass were re-run to 16 matches or more. Bands: each end 45 to 55 % of Elimination's rounds, the attackers
40 to 65 % of Attack / Defend's (`tools/balance.sh`).

RP1 (the replicas' balance, #319) merged while this task ran and moved the bots' fights, so every "after" below is
measured on the branch rebuilt on it (`main` at 055b438), and the "before" is `main`'s own map at that commit unless
a figure says "before RP1".

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
| Depot | 49 % ±4 (124 rounds) to 51 % ±5 (121) | 44 % ±6 (62) to 51 % ±6 (65) | 13 m, 6 % to 12 m, 5 % |
| Woodland | 55 % ±6 (60) to 50 % ±4 (173) | 56 % ±5 (120) to 59 % ±5 (117) | 40 m, 73 % to 20 m, 25 % |
| Subway | 55 % ±4 (127) to 54 % ±4 (127) | 46 % ±6 (59) to 52 % ±6 (60) | 7 m to 8 m, none |

### Depot (`tools/depot/layout.py`, `data/maps/depot.json`, 222 blocks, were 220; the bake rebuilt)

- **Found:** the lanes, links and ranges are sound (knock-outs at 13 m, 6 % over 30 m, rounds 45 s). Attack / Defend's
  defenders waited at the foot of the A stairs and the B ramp, outside the sites, and the poles stood in the open: on
  the two sites the attackers lost 203 and scored 70, and 78 defenders were caught on the stairs and the ramp; a flag
  went up in 27 % of rounds. Before RP1 Elimination leaned east (44 % ±3 for the west over 242 rounds), the west's
  squads sent 6 m deeper down the Chrono hall than the east's; with RP1's replicas the same layout reads 49 % ±4.
- **A site:** a crate stack at (41.5, -27.2) between the pole and both Offices doors and one at (46.2, -23.8) between
  it and the A stairs' mouth; the corner stack at (49.2, -26), behind the pole, is gone. **B site** mirrors it:
  (42.5, 27.6) and (47.0, 24.4) in, (50, 27) out.
- **Lanes:** the north and south lanes end on the sites, one post behind the flag stack and one at the low crate by
  the stairs (ramp) mouth; the middle lane's two are behind the Garage dog-leg's stacks. Each lane has one point
  about 4.5 m either side of the middle and none between; the middle lane's pair sits 0.8 m east of even (before RP1,
  dead even gave the west 55 % ±4 over 195 rounds and 0.8 m east 50 % ±5).
- **After:** on the sites 148 to 208, the median knock-out of Attack / Defend at 10 m (16) and 48 % inside 10 m
  (22 %); 22 defenders caught on the stairs and ramp; a flag goes up in 45 % of rounds and the attackers take 51 % ±6
  (44 % ±6). Elimination stays even (51 % ±5 over 16 matches). `tests/unit/test_baked_light.gd` counts the two blocks
  more.

### Woodland (`tools/woodland/layout.py`, `data/maps/woodland.json`, `tools/woodland/check.py`)

- **Found:** every lane was shot from end to end. The Ridge looked 86 m down the north lane, the Clearing 70 m over
  the Ford to Hut row, and the Long road ran 60 m with nothing on it under a hump 2.5 m over the road beyond. Of
  Elimination's knock-outs 73 % came from over 30 m (median 40 m; a round's first at 45 m; before RP1 71 %, 38 m and
  40 m). The win shares were in band (the west 55 % ±6 of Elimination, the attackers 56 % ±5; before RP1 46 % ±5 and
  61 % ±4 over 16 matches each), but the flags were taken from outside: round the two poles the attackers scored 309
  to 100 from about 30 m, the Fort's west side a low wall and flag B open to the road.
- **North:** five hazels on the Ridge's brow and three behind (the Brow hazel; a windthrow screen with one gap gave
  the west 30 %); a fallen tree at the North bridge's west head and a cordwood stack at its east; the Fort's west
  side a full wall with a window and a doorway, crates and a tyre stack inside, a fallen tree off its south side.
- **Middle:** a cordwood stack and hazels at the Birch stand (were two low crates); a fallen tree in the Clearing
  just past the field's middle, north of the straight way from the Ford to the overtime flag (across that way the
  east came 2.8 s after the west to the flag, and `test_woodland_layout` allows 2); two spruce thickets on the Ford's
  east bank, joined, with a hazel below and three on the crest at the head of the bank's ramp, 5 m wide; the Hut row
  crates deeper and double height, and a stack across the Back yard's mouth.
- **South:** three fallen trees across the Long road, staggered, the first on the hump's top (`tag="roadblock"`:
  `check.py` lets a piece meant to block the road stand on it); a cordwood stack across the road where the lane
  leaves the Culvert, a gate screen's 2.8 m, and one behind the west camp's road gate; at the Sawmill a stack between flag B and
  the road.
- **Lanes:** re-laid through the new pieces; the middle lane ends in the Back yard (it ended in the east camp). Each
  has one point either side of the field's middle, the middle lane's western one behind the Clearing's tree. The
  north lane's middle falls at the west end of the North bridge, a footbridge 1.8 m wide: the west's point is on the
  deck's first metres and the east's 2 m off that end by the fallen tree's root plate, so the lane is fought at the
  bridge's west head and the west is not sent over the deck. The south lane's last two, flag B's defenders, are behind the crates north of the road mouth and
  behind the flag's stack.
- **Passes:** fifteen layouts were measured (`pipeline/out/mb1/`, not committed). A screen with one gap on the Ridge
  gave the west 30 %. A fourth road tree and an open Ford each put the long lines back (26 m, 43 % over 30 m). A 2 m
  door between the Ford's thickets was a queue. A pen of two stacks round flag B gave the attackers 78 %. The road's
  stack at 1.8 m left one 52 m duel from the hump onto flag B's post, 88 of Attack / Defend's 142 knock-outs from over
  38 m; a gate screen's 2.8 m shuts it. The same stack 3.5 m further east was the attackers' cover onto the site
  (71 % of 126 rounds), so it stands where the lane leaves the Culvert. Flag B's forward defender in the road mouth
  took 80 of the 175 knock-outs the attackers scored there, from 25 m; behind the crates the attackers' share fell
  from 64 to 55 % (before RP1). With the north lane's western stop at the bridge's east end the west crossed the deck
  into the east's guns, lost that lane 133 to 187 and won 40 to 44 % of Elimination over three layouts; at the west
  end, 50 %. The first eight baseline matches read 43 % and 70 % and sixteen read 46 % and 61 %: the before is
  measured as long as the after.
- **After:** Elimination: the west 50 % ±4 over 24 matches (173 rounds); the median knock-out at 20 m (40), 25 %
  from over 30 m (73), a round's first at 17 m (45); by lane the north 26 m, the middle 19 m, the road 14 m (39, 41
  and 41), and no lane is lost by more than 349 to 308. Attack / Defend: the attackers 59 % ±5 over 16 matches
  (56 % ±5); 18 m (32) and 17 % over 30 m (55); round flag A they score 117 to 111 at 10 m (136 to 56 at 38 m), round
  flag B 138 to 94 at 9 m (173 to 44 at 25 m).

### Subway (`tools/subway/layout.py`, `data/maps/subway.json`; no block moved)

- **Found:** the closest fights of the three (median 7 m) on two of three floors: both poles stood on the south side
  (A on the south platform, B on the stair landing 11 m from it), so the north platform saw 1 % of Elimination's
  knock-outs and under 0.4 % of Attack / Defend's play time. Every attacker came down the middle stair, where the
  defenders scored 56 at its top for none lost, and a flag went up in 8 % of rounds (the attackers' 46 % ±6 came from
  knock-outs). One lane ran down the spiral stair, about 40 s for a bot, and rounds ran 72 s.
- **Flag B** stands on the north platform at (33, -7.8).
- **Lanes:** the north lane takes the lifts down and runs the north platform; the south lane takes the escalators'
  north lane (the middle lane their south one, as SM2 laid them) and the concourse to the middle stair, its last two
  points (the defenders' posts) the stair's landing and foot. None takes the spiral stair. The north lane has one
  point 4.45 m either side of the field's middle (QA found its stops 1.1 and 15 m deep).
- **After:** the north platform takes 16 % of Elimination's knock-outs and 37 % of Attack / Defend's (98 to 103); a
  flag goes up in 18 % of rounds (8 %); Elimination's rounds run 49 s (72) and Attack / Defend's 53 s (71); the stair
  top costs the attackers 33 (56). The win shares hardly move: the street end 54 % ±4 of Elimination over 16 matches
  (55 % ±4), at the band's upper edge both times, and the attackers 52 % ±6 (46 % ±6).

## Decisions

- **No field was resized or cut,** though the owner allowed it: the first knock-out comes 15 to 24 s into a round on
  all three, and Woodland's fault was its sight lines, which cover fixed. Depot's 65 m Chrono hall line stays (owner,
  DR1).
- **Subway's blocks stay where they are** while its model threads work on them: both of its faults were the flags'
  and lanes'.
- **Woodland's lanes differ in range** (the road 14 m, the Clearing 19 m, the north 26 m), so each replica class
  has a lane.
- **Woodland's road stack stands a gate screen's 2.8 m,** though the owner asked for the woodpiles "less tall"
  (2026-11-09): at a woodpile's 1.8 m the hump looks over it onto flag B's post. `test_wg2_woodland_models` allows
  the two heights; a play check asks him to look at it.
- **Woodland's attackers at 59 % are in the band's upper half** (40 to 65 %): the flags are now fought for on the
  sites, and the full balance pass measures it at 32 seeds.
- **Subway's Elimination stays at the band's upper edge** (the street end 54 % ±4; 55 % ±4 before; 50 % at PP1's 32
  seeds): moving a flag and the lanes did not move it apart from the noise, and the full balance pass measures it.
- **Measured at Normal, 6v6, by day.** Easy, Hard, the other team sizes and Woodland's night belong to the full
  balance report of the Dev 3 final pass (`tools/balance.sh`).

## Verified

VERIFIED
