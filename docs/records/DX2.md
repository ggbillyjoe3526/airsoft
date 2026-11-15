# DX2 · Depot's wall extras in Subway

**Review:** pending

The owner (2026-11-15), of DX1's new Depot models: "Can any of these new models be used in Subway map?", then "Add the
models in Subway where suitable." Look only: the station's cover, sight lines and balance stay as they are.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | passed | pending | – |

## What changed

- **Where they go** (`tools/subway/fixtures.py`, written into `dressing.station.fixtures` by `build_map.py`; no new
  models): a fire action notice with a call point beside it in the ticket hall, the concourse, the stair top and on
  each platform by its doors to the lower hall; fire points (hung 0.3 m) in the plant room, the stair top and the
  lift landing; a defibrillator sign in the ticket hall and the lower hall; a PPE sign in the plant room; "Fire exit,
  keep clear" beside the cross passage's mouth in each running tunnel. Signs at eye height (1.6 m, the owner's Depot
  rule), call points at 1.35 m, as on Depot. Every spot passes the station's checks (solid wall behind, in its room's
  air, in no block).
- **Pipework** (`PIPES`): pipe_run lengths with a 2 m one in the last gap, every third 4 m length the fitted
  pipe_run_b, along the ticket hall's long walls (from its street-end corner, its foot 3.05 m up) and the stair top's
  side walls (3.0 m, ending at the corner over the stair): over the posters' band and StationDetail's wall vents
  (top 2.92 m), under its conduit (0.2 m under the ceiling). 21 lengths, about 17k triangles, in StationFixtures' 40 m
  chunks. A length is checked for solid wall every 0.25 m behind it and kept 2 cm clear of every other fixture (the
  hall's cameras and clock); a fitted length whose drop would meet something under it (the ticket office's roof) is
  laid plain.
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

## Known issues left

- A pipe run ends in the open where a wall's length isn't a whole number of lengths (the hall's north run 1 m short
  of the concourse, the stair top's 1 m short of the passage's bulkhead), as Depot's end-wall runs do. How it looks in
  play is play check N21.
