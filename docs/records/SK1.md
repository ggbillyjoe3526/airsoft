# SK1 · Stockade, a dev-only field built for Plant The Bomb

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | build thread | pass | Retry 5/8 | dropped the concept's Bell tower, Tents, Orchard, campfire and 76 m depth unrecorded; the Green filled with 53 tall pieces; no MB1 before and after |
| 2026-11-13 | 2 | build thread | pass | pending | – |

## Goal

The owner, 2026-11-12 17:38: a new map built only from the existing maps' models and sounds (no greybox, no new
model or sound), playing unlike the others and balanced for Elimination, Attack / Defend and the new mode, Plant The
Bomb (PB1). He picked from three ideas at 17:54: "Build both Stockade and Stacks maps. They are dev only maps." At
22:56 he scrapped Stacks ("Do not build it"); it was never started. Stockade is concept 1 of
`/mnt/project-files/concepts/new-map-ptb/` (plan `idea-1-stockade-plan.png`, source `source/stockade.py`).

## Approach

- **The concept's plywood village inside a log fort**, 104 x 76 m on flat ground: the attackers (end 0) start in the
  West camp by its two Tents, the defenders in the East camp, each behind a palisade with three gates. Three ways run
  west to east: the Back Lane (north), Main Street through the West Arch onto the Green and its campfire, the
  Woodyard Road (south) past the Orchard. The Forge, Barn, Tavern and Store stand round the Green as the concept has
  them. Site A is indoors, the Long House at the north-east (30, -22); Site B the open Woodyard under the Sawmill's
  shed (31, 21). Attack / Defend's poles stand at (30, -9.5) and (32.5, 25.6), Elimination's overtime flag on the
  Green beside the fire.
- **Built by a script** (`tools/stockade/`): `layout.py` holds the buildings, walls, doors, roofs, ends, lanes, sites,
  areas and lights; `cover.py` every piece of cover; `build_map.py` writes `data/maps/stockade.json` (383 blocks: 179
  plywood, 83 palisade and fence, 61 logs and cordwood, 27 crates, 4 drums, 3 barrels, 2 sofas, 2 tyres, 1 sandbag
  wall, 21 trees; 23 doors, 26 lights); `check.py` checks overlaps, sight lines and walks and draws a plan; `hot.py`
  finds hot spots.
- **Only the game's models** (PropDressConfig): plywood walls and headers, hut roofs, the palisade, cordwood, crates,
  fallen logs, sandbags, drums, barrels, the sofa, tractor tyres, the Sawmill's shed, sawbench and boards, oaks and
  bushes; the woods' ambience; a day and a night preset with three fires and 23 lanterns.
- **The open Green:** 27 x 28 m between the houses, its middle 16 m clear but for the campfire's four log benches
  (0.6 m, crouch cover) and a sandbag wall before the Bell house. Its only tall pieces are the concept's four stacks
  at its corners, a screen in each alley's mouth and a crate stack in the Tavern's corner (9; attempt 1 had 53).
- **Sight lines** under FieldStandard's 34 m everywhere: 33.5 m by the game's own measure (FieldMeasure.sightline, as
  `test_field_layout` runs it). Long lines were found through lined-up doors, windows and fence gaps, and broken by
  moving the opening or by a piece of furniture in the room (a crate stack, the Tavern's shelves), never by cover
  dropped where a line ran. Pieces that meet run 1 cm into each other (within FieldStandard.SEAM_SLACK) so no line
  slips along a seam. `check.py`'s stand points now keep a body's clearance from every piece, as FieldMeasure's do.
- **Lanes** laid as MB1 asks: one point either side of the middle, 3 m (Back Lane), 6 m (the Green) and 3.5 m (the
  Woodyard Road) deep both ways, the last two points the Attack / Defend posts at each flag.

## Defaults taken

Claude's, each the owner's to change:

- Dev content, 6v6 standard, semi-auto start like Depot (close fights).
- Site A indoors, Site B in the open, so the two sites ask for different plays.
- Day by default, a night preset with fires and lanterns.

Departures from the concept (each so the field meets the 34 m line, or plays its three modes):

- **A Bell house in place of the Bell tower** (the owner's ruling, 2026-11-13: "Leave the tower out";
  DECISIONS › Maps and modes). Woodland's watch tower put a standing eye at 5 m: it saw over every 2.6 m wall, 3,839
  lines over 34 m, the longest 65 m to the attackers' gate. The house (6 x 9 m, one door to the east) stands across
  Main Street's east end, so the street is walked round it through its two yards.
- **Fenced courts and yards.** The concept leaves the ground between the houses open; plywood fences with one gate
  each make the North, House, South and Store courts, the Forge, Barn, House and Shed yards, so the outer lanes stay
  lanes and the courts are rooms of their own.
- **The Orchard behind a palisade** with two gates (x -29 and 7), its trees in two overlapping rows, a short woodpile
  either side of each gate on the road; the camps' south gates open onto the Woodyard Road, not the Orchard.
- **Chicanes of cordwood and palisade stubs** every 12 to 13 m down the Back Lane, the Woodyard Road and East Lane,
  and five woodpiles in each camp, from either side by turns.
- **The West Arch** is a dog-leg between its two huts with a crate stack in the middle; the concept's huts have one
  door each, these two (one onto the Arch, one onto the yard behind).
- **East Lane** runs behind a plywood fence from the House and Shed yards, Main Street its one way in.
- **Doors and windows moved** where two lined up into a line over 34 m (the Store's partition doorway to the east end,
  the Forge's front door and back window, the West Arch huts' doors, the Long House's west room given a crate stack).
- **Flag A in the House yard** before the Long House, between a crate stack and a woodpile (MB1: as Depot's flags
  stand), not at the concept's site door. Tried 3 m further west: Attack / Defend's attackers fell to 37 %, so it
  stayed at x 30.

## Measures

Bots only, Normal, 6v6, `tests/support/match_runner.gd`, sixteen seeds a mode:

| Mode | Rounds decided | Result |
|---|---|---|
| Plant The Bomb | 118 | attackers 47 %; armed 36 % of rounds (Site A 81 % of plants); none held up |
| Attack / Defend | 122 | attackers 44 %; first knock-out 20.8 s in, at 7.7 m (flag A 3 m west: 37 % of 125) |
| Elimination | 123 | west end 46 %; first knock-out 15.3 s in, at 10.7 m; overtime 4 of 123 |

Attempt 1 (104 x 64 m, the Green full of cover): Plant The Bomb attackers 45 %, armed 74 %; Attack / Defend 49 %;
Elimination west 46 %, first knock-out about 17 s in at 6 to 8 m.

MB1's tools, before (attempt 1's map, `413a8ed`) and after (this one), Elimination 6v6, the same eight seeds
(`tools/map_heat.gd`, `tools/map_survey.gd`, `tools/maps/plan.py`; pictures in
`/mnt/project-files/screenshots/stockade/mb1/`):

| | Before (104 x 64 m) | After (104 x 76 m) |
|---|---|---|
| Rounds, west end won | 64, 48 % ±6 | 61, 48 % ±6 |
| Round length, first hit | median 65 s; 17 s, from 6 m | median 68 s; 16 s, from 10 m |
| Knock-out range | median 6 m, 90th 13 m; 77 % under 10 m | median 9 m, 90th 18 m; 57 % under 10 m |
| Where people are hit | Green 42 %, Woodyard Road 20 %, Back Lane 16 %, the four houses and Arches 16 % | Green 34 %, Woodyard Road 27 %, Back Lane 25 %, Main Street 5 % |
| The Green: stand points, open to | 763, 2.9 % of the points in sight range | 936, 10.2 % |
| Longest standing line (survey, 1 m grid) | 33 m | 33 m |
| Flag A, flag B: walk from end 0 / end 1 | 22 / 7 s, 23 / 10 s | 22 / 6 s, 25 / 10 s |
| Overtime flag: end 0 / end 1 | 13.6 / 13.2 s | 13.5 / 14.2 s |
| Hardly used (under 0.4 % of time) | Barn, Barn yard, Forge, Forge yard, Long House | Barn, Bell house, Forge, Orchard, Store, Tents, West Arch |

The fights moved out of the houses onto the three ways and spread across them, at longer range; the Green is a
square you are seen on, as the concept means. The houses off the Green are hardly fought in at Elimination (bots
keep to their lanes); Plant The Bomb's Site A is the Long House, and the Orchard is a flank nobody takes yet.

## Checks

- `test_field_rules`, `test_field_layout`, `test_sk1_qa`, `test_dev_settings`, `test_nr1_qa` pass (65 tests);
  `check.py`: no overlaps, no line over 34 m (its quick sweep: 33.8 m), every spot reached.
- QA: pending (attempt 2).
- Performance: pending (attempt 2).

## Left for the owner

- How it plays: the play checks are on the Dev 3 checklist (SK1).
