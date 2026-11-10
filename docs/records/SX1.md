# SX1 · The Street removed

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (project thread) | lint, unit 1 to 4, smoke, notices green in CI on b01bf72 | Accept 8/8 | – |

## What changed

The owner (2026-11-09): "completely remove "the street" map from the game", then "make sure not to remove/break
anything the rest of the game uses". The Street was dev only (DT1).

- **Gone:** `data/maps/street.json` and its row in `data/maps.md`; its field picture and card; `tools/street/`; the
  Street guards (`tests/guards/test_street_guards.gd`) and their CI job; `test_street.gd`, `test_st2_qa.gd` and the
  Street-only tests in `test_st1_qa.gd`, `test_sr1_railings.gd` and `test_props.gd`; the 23 Kenney props only it
  dressed (seven cars, four vans, three lorries, three bins, a skip, a lamp, settee, table, units, fridge), their
  recipes in `tools/props/build_props.py`, their entries in `PropDressConfig` and their rows in `docs/ASSETS.md`;
  `FieldStandard`'s Street exceptions; its known issues, playtest checks and FEATURES lines; the wiki's In development
  entry.
- **Kept, used by the rest of the game or the map format:** the `street` ambience and its two recorded beds (the
  Range's sound, owner 2026-11-05); window glass (`MapStyle.clear_kinds`, BQ1) and bar railings (`Railings`, SR1),
  each tested on fixtures; a block's own colour; the flag head start exception; `MapStyle`'s town kinds (bins'
  plastic, the van's steel sound and the hoarding's finish are read elsewhere); the palette's town colours; the doors'
  narrow size (DM1 builds it); the trunk prop (Woodland's). The props tool keeps its `paint` parts, unused now, for
  a later vehicle.
- **Tests moved off the map:** the sniper balance tests hear over a flat 160 m floor instead of The Street's grid; the
  layout, summary, field map and frame-allocation tests use Depot or Woodland. New: The Street's files and props are
  gone, and a pick saved on it opens on Depot.
- **Wiki:** `tools/wiki.py` leaves notes naming The Street out of the Patch Notes (it was never public) and refuses a
  page naming it.

## Decisions

- **Keep the map-format features The Street brought** (default; the owner asked not to break what the rest uses):
  removing glass, railings or block colours would change engine code other maps can use, for no gain.
- **Keep the `street` ambience id and beds** (default): it names the sound, not the map, and the Range plays it.
- **Leave history alone** (default): records, the archive and `CHANGELOG.md` keep The Street as written.
