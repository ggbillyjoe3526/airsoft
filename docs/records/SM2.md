# SM2 · Subway's escalators, lifts, stairs and railing

**Review:** 1 attempt · critic pending · qa pending · performance pending

The owner (2026-11-12): "Begin work on subway models now." SM2 is models #14 to #18 of
`art/subway-model-list.md`: the escalator banks, the lift car and doors, the spiral stair, the stair handrails and
step nosings, and the balustrade railing, after the owner's photos in `art/references/maps/subway/14-escalator/` to
`18-railing/`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | – | – | – |

## What changed

- **Escalators** (`escalator.py`, 7,190 and 6,566 triangles of 8,000): each bank is one model laid over its ramp and
  its three decks (`PropDressConfig` SET). Each bank's two escalators are 1.2 m wide between their balustrades, two
  abreast (the owner, 2026-11-12: "Escalators need to be narrower. Only wide enough for 2 people."; they were 3.2 m):
  `layout.py` gives each bank a 2 m middle deck and a deck from each escalator to the wall, solid 1 m blocks on the
  slope like the old middle balustrade. The shafts, their walls and ceilings are unchanged. It has ribbed steps with yellow sides and nosings, landing plates and
  combs, newel-ended stainless balustrades, black handrails looping into their inlets, skirting brushes, stop buttons,
  and bronze uplighters on the middle deck.
- **Lifts** (`lift.py`): `LiftView` draws the car model (5,622 of 6,000) turned to its door, plus a landing doorway at
  each stop (728 of 1,200). The leaves (48) and push buttons (128 of 160) are scaled to each use. A lift unlike the
  model keeps the plain boxes: a different well, door or wall, or a door facing s or w (`LiftViewConfig.model_*`). The
  buttons are now real lift size (`button_size` 52 mm, was 90 mm). The car's inside is from general knowledge, as
  the list asks.
- **Spiral stair** (`spiral_stair.py`, 5,854 of 6,000): five risers a flight, with ribbed yellow nosings, the corner
  landings and soffits, and a black handrail on brackets up the outer wall. It is laid over the ten flights and nine
  landings; the core stays the station's tiled pillar.
- **Platform stair** (`platform_stair.py`, 1,968 of 2,000): two flights of twenty treads, each tread's middle on the
  ramp's slope (feet within 10 cm). The nosings are ribbed aluminium, yellow on the top and bottom steps, with a sloped
  tile skirting. Round steel handrails run down both walls, level over the half landing. The handrails stand 0.922 m
  over the ramps' box: `PropDressConfig.set_heads`, new, grows a SET model's fit by this much.
- **Railing** (`railing.py`): a kit of four pieces (a chamfered bar, the round-topped capping, the foot rail and a
  post). `RailingMesh` (`game/map/railing_mesh.gd`, `MapStyle.railing_look`) fits each piece to its bar or rail of
  `Railings.parts`, so the steel drawn is the steel a BB meets. Posts stand on panel-end bars, as wide along the run as
  a bar; floor plates sit inside the run's box. A 5 m run is 728 triangles of 800. MapLevel falls back to the old
  boxes if a piece can't be read.
- **Shared** (`transit_kit.py`): paints, a mesh builder, filleted tubes, knobs and rings, and `report`, which fails a
  model that is over budget or off its box by more than 5 mm. The props' shader draws ribs where UV.x is under -1
  (`map_kit.ribbed`, 8.5 mm pitch, fading to the average far off), for step cleats and nosings that triangles can't
  carry.
- **Map**: `layout.room(..., dress=)` and `SPIRAL["dress"]`. `build_map.py` writes them on the rooms' ramps, the
  escalators' decks and the spiral's landings in `data/maps/subway.json`. Apart from the escalators' decks, no box
  moves.

## Decisions

- **The escalators narrowed with decks, not narrower shafts**: the shafts keep their walls, ceilings and the openings
  into the halls, and the wide middle deck carries the uplighters as in the photos. The decks stop BBs and bodies,
  as the middle balustrade did; a player can't climb onto them (1 m, over the 0.95 m ledge).

- **No middle handrail on the platform stair** (the photos have one): it would stand in the walkway and stop nothing,
  so the stair keeps its full width.
- **The spiral's handrail ends below the top flight**, turned into the wall, so it stays inside the stair's box.
- **The escalator uplighters are unlit** shapes; the station's own lamps light the shafts.
- **Lift models only for lifts built like them**: Subway's two both match. Another map's lift keeps the boxes until a
  model is built for it.
- **The railing's posts add no steel a BB could meet**: they are a bar's width along the run and deeper across it. At a
  grazing angle a BB may pass a post's edge it seems to touch (2.5 cm).

## Known issues left

- The landing doorway uses 61 % of its budget and a leaf 16 %: both are flat steel in the photos, and more triangles
  would add nothing seen.
- A lift whose door faces s or w would need a mirrored car and landing model (none does today).
