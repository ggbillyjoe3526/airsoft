# RQ2 · The Range's skyline models rebuilt in detail

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | build thread (three workers, one per group) | ✓ touched tests (CI runs the rest) | | |

## Decisions

- **Asked for by the owner.** William, after RQ1's pictures (2026-11-17): "keep that, but i meant more detailed models
  in the background like the sheds/crane/water tower/ mast, etc." RQ1 (the firing point) stays; this rebuilds the nine
  skyline models the Range's background is made of.
- **From his photos.** Each model follows `art/references/maps/william-2026-11-09/skyline_buildings/<kind>/` closely:
  the sheds' doors, shutters, rooflights, gutters and downpipes; the jib crane's foot, I-beam jib, festoon cable and
  hoist; the phone mast's sections, step bolts, antennas, dishes and floodlights; the water tower's laced lattice legs,
  balcony and caged ladder; the silo's braced stand, hopper and pipes; the watch tower's stairs and cab; the fuselage's
  windows, doors, torn rear and broken tail.
- **Budgets raised about six times** (`skyline.py` BUDGETS, `test_skyline.gd` MODEL_BUDGETS): shed 2,600, long shed
  3,200, deep shed 3,000, crane 4,000, mast 3,600, fuselage 4,000, silo 3,200, watch tower 4,500, water tower 4,500
  (were 500 to 900). Each model uses 80 to 99 % (the fuselage 80 %: it read finished).
- **The skyline's cap 20k → 95k** (`TRIANGLES_MOST`). The Range's skyline mesh is about 89k triangles (was 10.1k), still
  one mesh and one draw call; Woodland's band is unchanged. A small cost on Low against what the owner asked for.
- **Bounds kept.** Every model keeps its old box (the water tower now exactly symmetric, 1 cm), so each piece stretches
  as before and `keep_depth` (the crane) behaves the same.
- **Reds kept off the team hues.** The crane's hook, isolator and pendant stop are raspberry #a82c68; the fuselage's
  cheat line wine #7e2046 over plum #4a2f55 (a plain red reads near High contrast's Beta orange in linear hue).
- **Only the masts' floodlights glow at night.** The sheds' bulkhead lamps are painted, not night-lit, so the night
  surface keeps four masts × four lamps (`test_skyline`) and Woodland's night look is unchanged.
- **Three modules** (`skyline_sheds.py`, `skyline_towers.py`, `skyline_hulls.py`) hold the builders; `skyline.py`
  keeps the entry point, budgets and shared colours.
- **Pictures:** `tools/range_pictures.gd` gains four views over the walls at the skyline (`sky_east`, `sky_west`,
  `sky_north_east`, `sky_south_east`).

## Known issues

- At 60 m and more the pieces take their own flat colour and the distance fade, so fine parts (chain, step bolts) read
  only as silhouette; the closer sheds, water tower and watch tower show the most.
