# SQ1 · Subway's station props in finer detail: gates, booths, benches, works wagons and tunnel parts (Beta)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | build thread and four workers | touched tests 134/134 | pending | – |

## Goal

The owner's second ask (2026-11-21): "I want all models improved", after the wagons (TQ1). This task is the
station's props: the ticket hall's gates, help points, crowd barriers, benches and staff booths, the works hoardings
and signal cabinets, the works siding's wagons, buffer stop, trolleys and cable drums, and the tunnels' segments, fan
housing and grille. Follow his photos (`references/maps/subway/`) closely, use about 95% of each budget, keep every
model's bounds, collision and the layout, Subway's orange (#c0652f) and no team hues.

## Approach

- **What each part is made of, in every prop kit** (`tools/blender/maps/surface_kinds.py`, new): TQ1's surface
  kinds (a face's UV y is 100 plus its kind) now come from `prop.py` (a `KINDS` paint table), `hallkit.py`,
  `works_kit.py`, `range_kit.py`, `map_kit.py` (beside its perforated and ribbed parts' UVs) and `transit_kit.py`.
  A new kind 8, satin paint (`look_surface.gdshaderinc`), for the gates', booths' and cabinets' painted panels; the
  stainless is satin steel, the screens and glazing dark glass, the seals and tyres rubber. A model with no kinds
  exports no UVs and is drawn as before.
- **Geometry**, each at 91 to 99% of its budget: the gates' rounded pedestals, glass screens, readers and paddles;
  the help point's speaker grille and buttons; the barriers' tubes and feet; the benches' perforated sheets and arm
  rests; the booths' glazing bars, counters and louvres; the hoardings' posts, braces and clamps; the cabinets' doors,
  hinges and vents; the wagons' underframes (shared by the ballast and engineering wagons), axleboxes, ribs and
  stanchions; the buffer stop's beams and buffers; the trolleys' wheels and decks; the drums' flanges and cable
  turns; the tunnel segments' bolt pockets, the fan housing's blades and guard, the grille's bars.
- **Near-black paints** stay at or above `slab*0.3`: darker tints round on import to a team hue (test_props found
  the gate's screen and the bench's holes).

## Verified

- Tests: the props, kinds, flicker, hall, fixtures, transit, Subway and train tests, 134 in 13 files, pass;
  `test_tq1_trains_qa.gd`'s "no prop outside the trains has kinds" is now "every prop with kinds has whole kinds only"
  (perforated and ribbed parts keep their own UVs).
- Faces: `tools/coplanar_models.py fix` on all 36 changed models, none left fighting, no bounds moved.
- Pictures, before and after (lavapipe, in game): `art/blender/subway-props/sq1/` in the project files.

## Left for the owner

- The look on his card and Low's frame time in the hall: N49 in the owner's checklist and docs/PLAYTEST.md's
  "Subway's station props up close".
