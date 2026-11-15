# DX2 · Depot's wall extras in Subway

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

The owner (2026-11-15), of DX1's new Depot models: "Can any of these new models be used in Subway map?", then "Add the
models in Subway where suitable." Look only: the station's cover, sight lines and balance stay as they are.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | passed | Accept 7/8 | check 8: two pipe runs ended in the open, 1 m short of a wall |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | passed | Accept 7/8 | check 8: the 1 m end length's front 11 cm stood past the concourse's 0.5 m return, its pipes open-ended |
| 2026-11-15 | 3 | Opus 5.5 (build thread) | passed | pending | – |

## What changed

- **Where they go** (`tools/subway/fixtures.py`, written into `dressing.station.fixtures` by `build_map.py`; no new
  models): a fire action notice with a call point beside it in the ticket hall, the concourse, the stair top and on
  each platform by its doors to the lower hall; fire points (hung 0.3 m) in the plant room, the stair top and the
  lift landing; a defibrillator sign in the ticket hall and the lower hall; a PPE sign in the plant room; "Fire exit,
  keep clear" beside the cross passage's mouth in each running tunnel. Signs at eye height (1.6 m, the owner's Depot
  rule), call points at 1.35 m, as on Depot. Every spot passes the station's checks (solid wall behind, in its room's
  air, in no block).
- **Pipework** (`PIPES`): pipe_run lengths with 2 m and 1 m ones in the last gap, every third 4 m length the fitted
  pipe_run_b, along the ticket hall's long walls (from its street-end corner to the concourse's wall, its foot 3.05 m
  up) and the stair top's side walls (3.0 m, from the corner over the stair to the passage's bulkhead), so every run
  ends at a wall: over the posters' band and StationDetail's wall vents
  (top 2.92 m), under its conduit (0.2 m under the ceiling). 21 lengths, about 17k triangles, in StationFixtures' 40 m
  chunks. A length is checked for solid wall every 0.25 m behind it and kept 2 cm clear of every other fixture (the
  hall's cameras and clock); a fitted length whose drop would meet something under it (the ticket office's roof) is
  laid plain.
- **pipe_run_1** (`depot_extras.py`, 300 triangles): a 1 m length to finish a run at a wall, with no bracket of its
  own (the next length's and the wall hold it), its pipes and cables capped at its far end: where the hall's runs
  meet the concourse's 0.5 m return, the main's and the basket's front 11 cm stand past the return's corner and show
  closed ends. Depot doesn't lay it. A test checks every run is laid end to end with a wall past both its ends.
- **The ticket hall's clock** (SM5's) moves from the south wall at -51 to the street-end wall, 3.4 m up as before, so
  the south run reaches the corner.
- **Pictures:** `tools/subway/station_pictures.gd` `extras` (EXTRA_SHOTS); the owner's sheets in
  `art/subway-extras-sx1/` (project files).
- **Tests:** `tests/unit/test_dx2_subway_extras.gd` (the models carried, their heights, the pipework's height, clearance
  and lengths); `test_station_fixtures.gd` now counts Depot's sheet and the pipework's chunks in Subway's view.

## Decisions

- **No racking, drum and IBC stacks or parts cage:** they are 3 m solid bays; Subway has no store room, and placing
  them means new blocks, so new cover. The works hoardings are closed blocks with nothing visible behind them.
- **No warehouse signs** (pallet storage, no riding on pallet trucks, the assembly point that says "Warehouse").
- **Safety colours kept**, not Subway's orange: fire action, defibrillator and fire exit signs read the same in a real
  station, and their green and fire red keep their meaning (DX1's colours are already off the team hues).
- **No second extinguisher:** SM5's stand where a station needs one.
- **Pipework not in the passages, plant room, lower hall or tunnels:** StationDetail already runs pipes and conduit in
  the passages and plant room; the 3.0 to 3.5 m rooms have no height over their vents and under their conduit for a
  0.7 m run; the running tunnels' 0.8 m walkway beside the wagons is too narrow for a 0.62 m deep run.

- **Depot's end-wall runs keep their 2 m gap at the corners:** the long walls' runs pass over them at the same
  height, so running them on would cross; finishing them needs an elbow piece, not a length.

## Known issues left

- None known.
