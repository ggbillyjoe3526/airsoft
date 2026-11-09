# FS1 · The flagpole and the Range's skyline buildings (Dev 3 map models, group 5)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | 114/114 targeted | Revise 5/8 | proportions against the photos (water tower, silo, watch tower, flagpole truck), stretched shed doors and windows, no windscreen, no face test, changelog |
| 2026-11-09 | 2 | Opus 5.5 (build thread) | 117/117 targeted | Revise 7/8 | a 12 mm gap under the flagpole's truck; curves flat-shaded (the water tower's bowl read as a cone) |
| 2026-11-09 | 3 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **Sources:** the owner's reference zip of 2026-11-09 (`art/references/maps/william-2026-11-09/flag_pole/` and
  `skyline_buildings/<kind>/`), the plan `art/depot-range-model-list.md` (flagpole 2,500 triangles; skyline 20k in
  all). Built by code: `tools/blender/maps/flagpole.py`, `skyline.py`, the shared `vertex_paint.py` (one vertex-coloured
  mesh in one material, like the Kenney props, colours written linear).
- **Flagpole (default):** the photos' sectional pole, black below and bare aluminium on top, twist-lock collars with
  thumb screws, ribbed marks, a flat cap (the ball finial came off at the owner's word, 2026-11-09). Kept from the
  old pole because the round's flag climbs it: the weighted base, the halyard's two runs (now into a round truck at
  the top, now 6.8 cm across, a little over the pole's 5 cm, so it doesn't read as a ball: the runs turn in to it
  13 cm under it) and the cleat, all at FlagViewConfig's sizes, so the cloth and ring sit as before. The overtime flag draws the same model scaled to its 2.3 m (default: one pole
  for all maps). The plain code-built pole stays the fallback when the model won't load.
- **Skyline kinds modelled:** shed, crane, mast, fuselage, silo, watch tower, water tower (the coordinator's list);
  containers, chimneys, power lines, hills and treelines keep their greybox. `SkylineConfig.models` names them; a
  missing model keeps its kind's greybox.
- **Fitting:** each model is stretched to fill its piece's box exactly (a shed's to its ridge, `roof_rise`). The shed
  comes in three sizes (26 x 14 x 6, 50 x 22 x 9, 40 x 26 x 8 m; `SkylineConfig.variants`) and each piece stands the
  one that stretches most evenly (`SkylineModels.best_of`), at most 1.3 times more one way than another on the Range
  (tested), so doors, windows and sheets keep their size; a silo row stands one model a drum
  (`SkylineShapes.silo_drums`) and keeps its walkway; the crane keeps its own depth (`keep_depth`) so a deep piece
  doesn't fatten its pillar. The fronts face the field as the greybox's did: a shed turns its shutter gable or its
  windowed side to it, the crane its jib, the mast its antennas and lamps, the towers their stairs.
- **Sight unchanged:** SkylineSight and `hides_of` still read the greybox parts, so the same pieces are seen and hide
  the same pieces; the models are drawing only (no collider, no nav).
- **Colours:** BODY faces take the piece's colour (the map file's or the kind's). `shed_colour` is now the photos'
  green (52634a; the six sheds the Range paints keep their pale colours); every fixed colour was checked against both
  colour sets' team hues in linear HSL, and the stripe went plum (a red read as High contrast's orange), the timber
  and glass greyer (`test_no_model_colour_reads_as_a_team_at_any_fade_step_by_day_or_night`).
- **Mast (default):** the photos' phone mast, keeping the Range's floodlight bar under the antennas because it lights
  the yard at night; its lamp glass (vertex alpha 0.5) is still the night's self-lit surface.
- **Watch tower:** its camouflage net and flag (SiteDress, DD1's greybox dressing) are left off when the tower is
  modelled: the photos have a plain roof, and the net no longer fits it.
- **Proportions after the photos (critic, attempt 1):** the water tower's legs stand about 1.7 times its tank and
  bowl, the bowl three quarters of its width deep, the drum two thirds of its width tall under a low roof that
  overhangs it (103841); the watch tower's open cab is two thirds of its legs' height, low corrugated panels and posts
  under a pitched hip roof overhanging the deck (103631, 103648); the silo's drum and top are 1.4 times its width and
  its hopper half the drum (103739, 103753); the fuselage has a six-pane windscreen (103958, 104028).
- **Silos lowered (default, to match the photos):** the photos' silo stands about 2.5 times its width; the Range's two
  rows stood 3.5 and 4.3 times (21 and 26 m on 6 m drums), which would have needed stilts or a tower of a drum. Both
  rows are 15 m in `data/maps/range.json`; easy to put back.
- **Budgets** (mine, under the plan's 20k): shed 500 (its long and deep sizes 660 and 600), crane 800, mast 500,
  fuselage 700, silo drum 650, watch tower 750, water tower 900; built at 468 (652, 586), 742, 500, 636, 590, 698 and
  870. The Range draws 10.1k triangles (was 3.0k; 21 of its 41 pieces seen now the sheds and silos are lower), Depot
  18.4k, still one mesh and one draw call; building the Range's takes about 35 ms once a match.
- **Open surfaces face out by rule (owner, 2026-11-09: the water tower showed the sky through it):** Builder's
  `recalc_face_normals` guessed the outside of open drums and cones wrongly, which the game culls as a hole.
  `vertex_paint.lathe` and `orient_loft` now turn every lathe, tube and band face outward by its profile (outside on
  the right as it walks the axis) or away from its rings' middle; flat bands name their side. `test_model_faces.gd`
  rays every model from all round and above and fails it if more than 2 % first meet a face turned away (an
  all-flipped water tower scores 100 %); it found the mast's side panels and the fuselage's tailplane, now two-sided.
- **Sheds lowered (owner, 2026-11-09, "make the sheds less tall"):** the Range's eleven sheds stand at 0.65 of their
  height (rounded to 0.5 m: 9 m eaves to 6 m, the tallest 15 m to 10 m) in `data/maps/range.json`, so sight is
  worked out from the lower boxes; the sheds are built with their shutter, door and tall windows (103332) at real
  sizes.
- **Curves shade smooth (critic, attempt 2):** lathes' and tubes' sides are smooth-shaded, split sharp past 35° (a
  profile's corner, a 4- or 6-sided beam), everything else flat (`vertex_paint.SMOOTH_MOST`); no triangles added. The
  face test reads each triangle's winding, as the game culls, not its stored normals.
- **Flag pole model cached:** `FlagViewConfig.pole_mesh()` loads it once and warns once if it won't load (QA), as
  `SkylineConfig.model_of` does; a skyline model without vertex colours or an index counts as not loading.
- **Pictures:** the Range's card (`assets/maps/range.jpg`) and the wiki's range picture re-rendered.
  `tools/model_turnaround.gd` draws a model alone for review pictures.

## Known issues left

- None known.
