# SK1 · Stockade, a dev-only field built for Plant The Bomb

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | build thread | pass | Retry 5/8 | dropped the concept's Bell tower, Tents, Orchard, campfire and 76 m depth unrecorded; the Green filled with 53 tall pieces; no MB1 before and after |
| 2026-11-13 | 2 | build thread | pass | Retry 4/8 | Attack / Defend 44 % (under Normal's 45 to 55) and Site B hardly planted; houses off every route; MB1 figures quoted from a map with lines over 34 m; `check.py` copied MB1's tools |
| 2026-11-13 | 3 | build thread | pass | Retry 6/8 | the Forge, Barn and courts still hardly fought in; test fixtures committed by mistake; DECISIONS and the changelog note stale |
| 2026-11-13 | 4 | build thread | pass | Accept 7/8 | – (the changelog note's door count fixed before merge) |

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
  them. Site A is indoors, the Long House's west room at the north-east (26, -21); Site B the open Woodyard under the
  Sawmill's shed (31, 21). Attack / Defend's poles stand at (30, -9.5) and (32.5, 25.6), Elimination's overtime flag on the
  Green beside the fire.
- **Built by a script** (`tools/stockade/`): `layout.py` holds the buildings, walls, doors, roofs, ends, lanes, sites,
  areas and lights; `cover.py` every piece of cover; `build_map.py` writes `data/maps/stockade.json` (382 blocks: 176
  plywood, 83 palisade and fence, 61 logs and cordwood, 29 crates, 4 drums, 3 barrels, 2 sofas, 2 tyres, 1 sandbag
  wall, 21 trees; 26 doors, all open at the start, 26 lights); `check.py` checks overlaps and, on MB1's sight raster
  (`tools/maps/los.py`, `plan.py`), the long standing lines, each confirmed by an exact box test (the raster lets a
  line slip past the corner of a wall thinner than its 25 cm cells: three such 35 to 37 m lines, all blocked).
- **Only the game's models** (PropDressConfig): plywood walls and headers, hut roofs, the palisade, cordwood, crates,
  fallen logs, sandbags, drums, barrels, the sofa, tractor tyres, the Sawmill's shed, sawbench and boards, oaks and
  bushes; the woods' ambience; a day and a night preset with three fires and 23 lanterns.
- **The open Green:** 27 x 28 m between the houses, its middle 16 m clear but for the campfire's four log benches
  (0.6 m, crouch cover) and a sandbag wall before the Bell house. Its only tall pieces are the concept's four stacks
  at its corners, a screen in each alley's mouth and a crate stack in the Tavern's corner (9; attempt 1 had 53).
- **Sight lines** under FieldStandard's 34 m everywhere: 33.9 m by the game's own measure (FieldMeasure.sightline, as
  `test_field_layout` runs it). Long lines were found through lined-up doors, windows and fence gaps, and broken by
  moving the opening or by a piece of furniture in the room (a crate stack, the Tavern's shelves), never by cover
  dropped where a line ran. Pieces that meet run 1 cm into each other (within FieldStandard.SEAM_SLACK) so no line
  slips along a seam. `check.py`'s stand points now keep a body's clearance from every piece, as FieldMeasure's do.
- **Lanes** laid as MB1 asks: one point either side of the middle, 3 m (Back Lane), 6 m (the Green) and 3.5 m deep
  both ways, the last two points the Attack / Defend posts at each flag. The south lane runs through the Store, in
  at its yard door and out at its east door, then over the Store court into the Woodyard's west gate.
- **Routes through the houses (attempt 3):** the Forge, Barn, Tavern and Store have a second door each, so every
  house on the Green is a way through, not a room off it, and the Long House's east door, shut at the start in
  attempt 2, is open: a second way onto Site A from East Lane. The Bell house has a door onto the Green as well as
  the street, the two off each other's line with its stock between them, so the street is walked through it and the
  East camp reaches the Green as soon as the West camp (FieldStandard: 57.6 and 58.6 m to the overtime flag).

## Defaults taken

Claude's, each the owner's to change:

- Dev content, 6v6 standard; replicas start on their own selector, as on Woodland (an outdoor field: NA1's semi start
  is for indoor ones).
- Site A indoors, Site B in the open, so the two sites ask for different plays.
- Day by default, a night preset with fires and lanterns.

Departures from the concept (each so the field meets the 34 m line, or plays its three modes):

- **A Bell house in place of the Bell tower** (the owner's ruling, 2026-11-13: "Leave the tower out";
  DECISIONS › Maps and modes). Woodland's watch tower put a standing eye at 5 m: it saw over every 2.6 m wall, 3,839
  lines over 34 m, the longest 65 m to the attackers' gate. The house (6 x 9 m) stands across Main Street's east end,
  a door onto the street behind and one onto the Green, off each other's line, its stock stacked between them.
- **Fenced courts and yards.** The concept leaves the ground between the houses open; plywood fences make the North,
  House, South and Store courts and the Forge, Barn, House and Shed yards, so the outer lanes stay lanes. Each court
  has one gate on its outer way and its alley onto the Green, and the doors of the houses round it, so every court is
  a cross-route between an outer way and the Green; in attempt 3 the Forge (the Back Lane to the Forge yard and Main
  Street) and the Barn (the Woodyard Road to the Barn yard and Main Street) are ways through as well. Second gates in
  the courts' outer fences, tried in attempt 3, lined up with the house doors into lines over 34 m.
- **The Orchard behind a palisade** with two gates (x -29 and 7), its trees in two overlapping rows, a short woodpile
  either side of each gate on the road; the camps' south gates open onto the Woodyard Road, not the Orchard.
- **Chicanes of cordwood and palisade stubs** every 12 to 13 m down the Back Lane, the Woodyard Road and East Lane,
  and five woodpiles in each camp, from either side by turns.
- **The West Arch** is a dog-leg between its two huts with a crate stack in the middle; the concept's huts have one
  door each, these two (one onto the Arch, one onto the yard behind).
- **East Lane** runs behind a plywood fence from the House and Shed yards, Main Street and the Long House's east
  door its ways in.
- **Site A in the Long House's west room** (26, -21), not on the partition's doorway (30, -22): with the east door
  open, a site on the doorway was the defenders' the moment they came in.
- **Doors and windows moved** where two lined up into a line over 34 m (the Store's partition doorway to the east end,
  the Forge's front door and back window, the West Arch huts' doors, the Long House's west room given a crate stack).
- **Flag A in the House yard** before the Long House, between a crate stack and a woodpile (MB1: as Depot's flags
  stand), not at the concept's site door. Tried 3 m further west: Attack / Defend's attackers fell to 37 %, so it
  stayed at x 30.

## Measures

Bots only, Normal, 6v6, `tests/support/match_runner.gd`; Attack / Defend and Plant The Bomb over 32 seeds (8-seed
blocks swing by 10 points or more), Elimination over 16:

| Mode | Rounds decided | Result |
|---|---|---|
| Attack / Defend | 234 | attackers 49 % ±3 (seeds 1 to 16: 52 % of 115); first knock-out 21 s in, at 8 m |
| Plant The Bomb | 239 | attackers 40 % ±3 (seeds 1 to 16: 46 % of 126, seeds 17 to 32: 33 %); armed in 49 % of rounds, Site A 63 and Site B 54 of the plants |
| Elimination | 119 | west end 52 % ±5; first knock-out 15 s in, at 11 m; overtime 4 |

No bot was held up but one, once, in Elimination (seed 9 to 16 block). Plant The Bomb runs under its band on every
field (PB1: Depot 37 %, Woodland 41 %, Subway 48 %); its fuse and defuse are PlantConfig's, not the map's.

Attempt 2 (same seeds, 16): Plant The Bomb 47 %, armed 36 % (Site A 81 % of plants); Attack / Defend 44 %;
Elimination west 46 %. Attempt 1 (104 x 64 m, the Green full of cover): 45 %, 49 %, 46 %.

What attempt 3 tried for Attack / Defend and Plant The Bomb (attackers' share; seeds in brackets), each on the one
before unless said:

| Layout | Attack / Defend | Plant The Bomb |
|---|---|---|
| Lanes through the Tavern and the Long House, a second door on each house | 39 % (32) | 31 % (16) |
| The House yard's gate off Main Street shut, the defenders onto flag A through the Long House only | 68 % (16) | – |
| ... with a gap from East Lane into the yard | 43 % (32) | 37 % (16) |
| ... the gate a door, shut at the start | 38 % (16) | – |
| ... the gate 14 m further west | 30 % (16) | – |
| The Long House's east door at its south end, the gate shut | 58 % (32) | 36 % (16) |
| ... the north lane back on the Back Lane, not through the Tavern | 57 % (32) | 44 % (32) |
| ... and a door on the Bell house onto the Green (FieldStandard's walks: 57.6 and 58.6 m) | 77 % (32) | 54 % (32) |
| ... and the House yard's gate back (this field) | 49 % (32) | 40 % (32) |
| ... and the north and south lanes through the Forge and the Barn | 42 % (16) | 38 % (16) |

The defenders' walk onto flag A decides Attack / Defend (30 m: about 40 %; 42 m: 57 %; 55 m: 68 %); a lane through
the Tavern cost the attackers 10 points of Plant The Bomb; Site B moved 3 m west (34 %) or Site A 1.5 m (41 %)
changed nothing measurable over 16 seeds. The lanes stay off the Forge and the Barn: through them the attackers lost
about 10 points in both modes.

MB1's tools, before (attempt 1's map, `413a8ed`) and after (attempt 3's), Elimination 6v6, the same eight seeds
(`tools/map_heat.gd`, `tools/map_survey.gd`, `tools/maps/plan.py`; pictures in
`/mnt/project-files/screenshots/stockade/mb1/`):

| | Before (104 x 64 m) | After (104 x 76 m) |
|---|---|---|
| Rounds, west end won | 64, 48 % ±6 | 58, 53 % ±7 |
| Round length, first hit | median 65 s; 17 s, from 6 m | median 66 s; 16 s, from 11 m |
| Knock-out range | median 6 m, 90th 13 m; 77 % under 10 m | median 9 m, 90th 19 m; 57 % under 10 m |
| Where people are hit | Green 42 %, Woodyard Road 20 %, Back Lane 16 %, the four houses and Arches 16 % | Green 40 %, Back Lane 22 %, Woodyard Road 11 %, Store 9 %, Main Street 5 %, Tavern 4 % |
| The Green: stand points, open to | 763, 2.9 % of the points in sight range | 931, 10.3 % |
| Longest standing line (survey, 1 m grid) | 33 m | 33 m |
| Flag A, flag B: walk from end 0 / end 1 | 22 / 7 s, 23 / 10 s | 22 / 6 s, 27 / 10 s |
| Overtime flag: end 0 / end 1 | 13.6 / 13.2 s | 13.5 / 13.7 s |
| Hardly used (under 0.4 % of time) | Barn, Barn yard, Forge, Forge yard, Long House | Barn, Bell house, Forge, Orchard, Tents, West Arch |

The fights moved out of the houses onto the three ways and the Green, at longer range; the Green is a square you are
seen on, as the concept means. The Store and the Tavern are on routes now (13 % of the knock-outs, against none in
attempt 2's after); the Forge and the Barn stay quiet at Elimination, behind the West camp's own lines, and the
Orchard is a flank nobody takes yet. The attackers' walk to the flags is still 22 and 27 s against the concept's 15
and 14: Attack / Defend came into its band through the routes the defenders and the East camp take (above), not by
cutting the attackers' chicanes, which break lines over 34 m.

## Checks

- `test_field_rules`, `test_field_layout`, `test_sk1_qa`, `test_dev_settings`, `test_nr1_qa` pass (74 tests, 3 min
  20 s headless); FieldMeasure's longest line 33.9 m; `check.py`: no overlaps, no line over 34 m.
- QA: Pass, 16 tests of its own (`tests/unit/test_sk1_qa.gd`: loads clean, dev only, both lighting presets, sites,
  poles, flag and bomb start reached from both ends, no standable roof, no floor cut off; and in attempt 2 MB1's lane
  rules as `test_mb1_layouts` checks the shipped fields, the doors (26 in attempt 3, all open), the Orchard's gates,
  the Bell house's doors and a seeded bot match with no bot held up; in attempt 3 four minutes of play, not a whole
  match, which took about 190 s headless). Attempt 3, QA: Pass; the Tavern's north door moved 0.5 m off the Back
  Lane's woodpile its open leaf folded over; the Barn's east door's leaf still folds 10 cm over the woodpile at the
  Barn's corner (moving either opened a 39 m line; cosmetic, nobody is blocked).
- Performance: Pass. Attempt 3: map load 37 ms (Depot 7 to 10, Woodland 141 to 151), nav build 1.09 s (0.98, 3.5),
  382 blocks against Woodland's 960, 26 lights within LightPools' 32, `test_sk1_qa` 127 s alone (16 tests); frame time
  at night on Low is on the checklist.

## Owner's rulings

- **Bots are not sent through the Forge and the Barn (owner, 2026-11-13):** asked whether the bot lanes should run
  through them at about 10 points of the attackers' wins in Attack / Defend and Plant The Bomb, he chose "Leave it to
  your playtest": the houses stay ways through for players, the bots keep to the outer ways, and he judges the houses
  in play.

## Left for the owner

- How it plays: the play checks are on the Dev 3 checklist (SK1).
