# DX1 · Depot's new storage and wall extras from the owner's photos

**Review:** pending

The owner (2026-11-15), with `depot-prop-refs.zip`: "here are the reference images for the new models." The brief:
Depot has too many shelves; build pallet racking with shrink-wrapped loads, pallet stacks of drums and IBC totes, a
caged mesh parts store and wall extras (cable reels, fire points, signs, pipework) from the photos, and use the first
three in place of some shelves, each on the same footprint, height and solidity, so sight lines, cover and balance
don't change (the Chrono hall's 65 m line stays open); the extras go on walls and pillars and change nothing on the
floor.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## What changed

- **Three new rack bays, two of each** (`tools/blender/maps/wrapped_racking.py`, `drum_ibc_stack.py`,
  `parts_cage.py`, shared parts in `bay_kit.py`): 2.7 x 3.0 x 0.9 m like `pallet_racking.py`'s, front to -y, so
  PropLayout lays them as it lays the racking (`Lay.TILE`, dark backing half a row in, the two bays taking turns,
  never the same side by side, 40 m chunks, no shadow). 1,108 to 1,500 triangles of the bay's 1,500.
- **Which blocks:** `tools/depot/extras.py` `rack_dress` gives each `dead` piece a `dress` in turn (racking, wrapped
  racking, drums and IBCs, racking, parts cage), the two 108 m strips along the long walls staying racking: 24 of
  Depot's 48 rack blocks. The blocks' boxes are untouched (the map's blocks match the old file's but for `dress`), so
  collision, nav, cover, sight lines and the baked light (its hash covers kind, place and size, not dress) are as
  they were: no rebake.
- **Wall extras** (`depot_extras.py`, the signs' sheet by `depot_signs.py` with cells in `depot_cells.py`): a fire
  point board, a call point, a cable reel, 4 m and 2 m lengths of pipework, and seven safety signs. They are
  `MapData.fixtures` (`dressing.fixtures`, read by `StationDressing.read_fixtures`), drawn by StationFixtures as
  Subway's extras are: one MultiMesh a model, no collider, no shadow; a model may print from its own sheet
  (`StationFixturesConfig.sheets`).
- **Where the extras go** (`extras.py` `fixtures`, written by `build_map.py`): pipework along every hall wall at
  5.6 m (over the shutters' coil boxes, under the rooflights), a length between columns, the end walls' stopping 2 m
  short of the corners under the long walls' runs; high signs over the racking every third spot beside a column;
  fire points 0.9 m beside a column on an open wall, 20 m apart along it, then cable reels and the eye-height signs
  on the spots left, 6 m from any other; a "Fire exit, keep clear" sign beside each fire exit's door; a call point
  and an extinguisher on each pillar's post facing the hall's middle. Every spot is checked clear of the blocks in
  front of it, so the extras follow any layout. The feature bays (shutters, exits) are found by the same rule as
  `PropLayout._bays`; the test checks the two agree.

## Decisions

- **Same boxes, new dress** rather than splitting blocks: a split changes the baked light's hash and the block
  counts tests hold, for no gain; a whole block in one kind reads as a storage area, as in a real warehouse.
- **Colours off the team hues:** the photos' blue drums are violet, black and grey; the copper pipes are a red
  sprinkler main and aluminium-clad lagging; the fire red is the palette's new `fire` (#ac2264), leaning crimson
  like Subway's extinguisher red, so no prop reads as Beta in High contrast.
- **The exit bays keep their own extinguisher and call point**, so fire points stay out of them; fire points and
  reels stand 0.9 m from a column, clear of a shutter's opening and posts (2.53 m from its bay's middle).
- **The pipework is drawn in 40 m chunks** (`StationFixturesConfig.chunks`, performance's advice): 92 lengths
  round the hall, about 66k triangles, in one hall-wide MultiMesh would never cull.
- **Pillar signs left out:** a flat sign on the 0.4 m round post would stand off it at its edges; the call point and
  extinguisher are small enough to sit on it.

## Known issues left

- None known. How it looks in play on the owner's cards is play check N16.
