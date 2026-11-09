# FS1 · The flagpole and the Range's skyline buildings (Dev 3 map models, group 5)

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **Sources:** the owner's reference zip of 2026-11-09 (`art/references/maps/william-2026-11-09/flag_pole/` and
  `skyline_buildings/<kind>/`), the plan `art/depot-range-model-list.md` (flagpole 2,500 triangles; skyline 20k in
  all). Built by code: `tools/blender/maps/flagpole.py`, `skyline.py`, the shared `vertex_paint.py` (one vertex-coloured
  mesh in one material, like the Kenney props, colours written linear).
- **Flagpole (default):** the photos' sectional pole, black below and bare aluminium on top, twist-lock collars with
  thumb screws, ribbed marks, a flat cap (the ball finial came off at the owner's word, 2026-11-09). Kept from the
  old pole because the round's flag climbs it: the weighted base, the halyard's two runs (now into a round truck at
  the top) and the cleat, all at FlagViewConfig's sizes,
  so the cloth and ring sit as before. The overtime flag draws the same model scaled to its 2.3 m (default: one pole
  for all maps). The plain code-built pole stays the fallback when the model won't load.
- **Skyline kinds modelled:** shed, crane, mast, fuselage, silo, watch tower, water tower (the coordinator's list);
  containers, chimneys, power lines, hills and treelines keep their greybox. `SkylineConfig.models` names them; a
  missing model keeps its kind's greybox.
- **Fitting:** each model is built at its kind's first Range piece's size and stretched to fill its piece's box exactly
  (a shed's to its ridge, `roof_rise`), so its proportions carry over; a silo row stands one model a drum
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
- **Budgets** (mine, under the plan's 20k): shed 500, crane 800, mast 500, fuselage 700, silo drum 650, watch tower
  1,000, water tower 900; built at 468, 742, 496, 632, 614, 956 and 868. The Range draws 13.6k triangles (was 3.0k;
  23 of its 41 pieces seen), still one mesh and one draw call; building it takes about 40 ms once a match.
- **Open surfaces face out by rule (owner, 2026-11-09: the water tower showed the sky through it):** Builder's
  `recalc_face_normals` guessed the outside of open drums and cones wrongly, which the game culls as a hole.
  `vertex_paint.lathe` and `orient_loft` now turn every lathe, tube and band face outward by its profile (outside on
  the right as it walks the axis) or away from its rings' middle; flat bands name their side.
- **Sheds lowered (owner, 2026-11-09, "make the sheds less tall"):** the Range's eleven sheds stand at 0.65 of their
  height (rounded to 0.5 m: 9 m eaves to 6 m, the tallest 15 m to 10 m) in `data/maps/range.json`, so sight is
  worked out from the lower boxes; the shed model is built at 6 m eaves with its shutter and windows to suit.
- **Pictures:** the Range's card (`assets/maps/range.jpg`) and the wiki's range picture re-rendered.
  `tools/model_turnaround.gd` draws a model alone for review pictures.

## Known issues left

- None known.
