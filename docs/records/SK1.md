# SK1 · Stockade, a dev-only field built for Plant The Bomb

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | build thread | pending | pending | – |

## Goal

The owner, 2026-11-12 17:38: a new map built only from the existing maps' models and sounds (no greybox, no new
model or sound), playing unlike the others and balanced for Elimination, Attack / Defend and the new mode, Plant The
Bomb (PB1). He picked from three ideas at 17:54: "Build both Stockade and Stacks maps. They are dev only maps." At
22:56 he scrapped Stacks ("Do not build it"); it was never started. Stockade is concept 1 of
`/mnt/project-files/concepts/new-map-ptb/` (plan `idea-1-stockade-plan.png`, source `source/stockade.py`).

## Approach

- **A plywood village inside a log fort**, 104 x 64 m on flat ground: the attackers (end 0) start in the West camp,
  the defenders in the East camp, each behind a palisade gate. Three ways run west to east (the Back Lane, Main
  Street through the Green, the Woodyard Road), joined by two Arches, the Tavern and the Store, fenced courts and
  yards. Site A is indoors, the Long House at the north-east (31, -20); Site B the open Woodyard under its shed
  (32, 15). Attack / Defend's poles stand at (30.5, -9) and (32, 21.5), Elimination's overtime flag on the Green.
- **Built by a script** (`tools/stockade/`): `layout.py` holds the buildings, walls, doors, roofs, ends, lanes,
  sites, areas and lights; `cover.py` every piece of cover; `build_map.py` writes `data/maps/stockade.json` (450
  blocks: 192 plywood, 75 crates, 70 fence, 51 logs, 28 tyres, 11 barrels, 8 drums, 7 sandbags, 3 sofas, 5 trees; 26
  doors, 25 lights); `check.py` checks overlaps, sight lines and walks and draws a plan; `hot.py` finds hot spots.
- **Only the game's models** (PropDressConfig): plywood walls and headers, hut roofs, the palisade, cordwood, crates,
  fallen logs, sandbags, drums, barrels, the sofa, the Sawmill's shed, sawbench and boards, trees and spruces; the
  woods' ambience; a day and a night preset with two fires and 23 lanterns.
- **Dev content:** its row in `data/maps.md` is tagged dev (6v6, 5 to 8 a side, semi-auto start as at Depot).
- **Sight lines** under FieldStandard's 34 m everywhere (longest 33.3 m by the game's own measure): the walls run 1
  cm into what they meet so no line slips along a seam, and the long lines left by the first layout were broken by
  pieces placed against the game's own `FieldMeasure.sees`.
- **Lanes** laid as MB1 asks: one point either side of the middle, about equally deep. The north lane's first point
  past the middle was 0.5 m east of it for the west and 10 m west of it for the east; moved to 5.5 m each side, the
  west end's share of Elimination's rounds went from 41 % to 46 %.

## Defaults taken

Claude's, each the owner's to change:

- Dev content, 6v6 standard, semi-auto start like Depot (close fights).
- Site A indoors, Site B in the open, so the two sites ask for different plays.
- Day by default, a night preset with fires and lanterns.

## Measures

Bots only, Normal, 6v6, `tests/support/match_runner.gd`, sixteen seeds a mode:

| Mode | Rounds | Result |
|---|---|---|
| Plant The Bomb | 121 | attackers 45 %; armed 74 % of rounds (Site A 60 % of plants); none held up |
| Attack / Defend | 114 | attackers 49 % |
| Elimination | 126 | west end 46 % (after the lane fix; 41 % before); first knock-out about 17 s in, at 6 to 8 m |

## Checks

- `test_field_rules` and `test_field_layout` pass for Stockade; `check.py`: no overlaps, no line over 34 m, every
  spot reached.
- QA: Pass, 7 tests of its own (`tests/unit/test_sk1_qa.gd`: loads clean at 6 and 8 a side, dev only, both lighting
  presets, sites, poles, flag and bomb start on walkable floor and reached from both ends, no standable roof, no
  floor cut off).
- Performance: Pass by comparison with the shipped fields (450 blocks against Woodland's 945, 25 lights within
  LightPools' 32); frame time at night on Low is on the checklist.

## Left for the owner

- How it plays: the play checks are on the Dev 3 checklist (SK1).
