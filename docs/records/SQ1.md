# SQ1 · Subway's station props in finer detail: gates, booths, benches, works wagons and tunnel parts (Beta)

**Review:** critic Accept 8/8 (attempt 2) · qa Pass (e3096df) · performance Pass (e3096df)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | build thread and four workers | touched tests 134/134, QA Pass, performance Pass | Retry 6/8 | fidelity to the photos (the gates' dark body, the booths grey with black panes, the skip's pale spoil and shallow tub, segments, help point and barrier unchanged at range), no changelog note, ASSETS rows missing |
| 2026-11-21 | 2 | build thread and four workers | touched tests 166/166, QA Pass, performance Pass | Accept 8/8 | – |

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
- **After the critic (attempt 1):** the gate's pedestal is brushed stainless up to the reader head (dark share of
  the pillar 0.18, the photos' 0.19), with two small sensor windows a side; the paddle blade lowered to 0.47-0.95 m so
  the screen posts stand over it as in the photos (GatePaddles reads only the paddle's length, so its height is
  free). The booths are cream (`satin_cream`, grime at most 0.15) with clear grey glass in grey frames, the sill at
  half the eave's height and a 0.27 m roof fascia. The skip's spoil is shaded flat in about 5 cm facets of darker
  tones, its tub 1.6 times the undercarriage's height (smaller wheels, a lower frame). The tunnel segments are a
  1.34 m bore, so their arc reads at 10 m, with 6 to 8 cm deep bolt pockets. The help point is a red map totem
  (crimson, the house red: a true red is within 20 degrees of the high-contrast Beta orange) with recessed windows, a map, a street map, a timetable and the
  help panel. The barrier keeps its cover sheet (its block stops BBs and sight, so open bars would show gaps no shot
  goes through) but gains round corners, bridge feet, hooks and eyes, the sheet tied on with a hem.
- **Pictures:** close-ups (2.3 m) in game and each model beside its photo in Blender, in the project files.
- **Near-black paints** stay at or above `slab*0.3`: darker tints round on import to a team hue (test_props found
  the gate's screen and the bench's holes).

## Verified

- Tests: the props, kinds, flicker, hall, fixtures, transit, Subway, train, dress and QA's box tests, 166 in 15 files,
  pass;
  `test_tq1_trains_qa.gd`'s "no prop outside the trains has kinds" is now "every prop with kinds has whole kinds only"
  (perforated and ribbed parts keep their own UVs).
- Faces: `tools/coplanar_models.py fix` on all 36 changed models, none left fighting, no bounds moved.
- Pictures, before and after (lavapipe, in game): `art/blender/subway-props/sq1/` in the project files, with
  `close/` (2.3 m) and `vs-ref/` (each rebuilt model beside its photo).

## Left for the owner

- The help point's crimson reads a dark maroon in game; a true red needs a prop colour exception (his call), and the
  skip wagon keeps its stubby 2 x 2.7 m block (a longer, lower box would change the layout).
- The look on his card and Low's frame time in the hall: N49 in the owner's checklist and docs/PLAYTEST.md's
  "Subway's station props up close".
