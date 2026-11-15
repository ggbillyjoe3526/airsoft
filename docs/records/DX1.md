# DX1 · Depot's new storage and wall extras from the owner's photos

**Review:** pending

The owner (2026-11-15), with `depot-prop-refs.zip`: "here are the reference images for the new models." The brief:
Depot has too many shelves; build pallet racking with shrink-wrapped loads, pallet stacks of drums and IBC totes, a
caged mesh parts store and wall extras (cable reels, fire points, signs, pipework) from the photos, and use the first
three in place of some shelves, each on the same footprint, height and solidity, so sight lines, cover and balance
don't change (the Chrono hall's 65 m line stays open); the extras go on walls and pillars and change nothing on the
floor. After the first pictures, the owner: "Make variations of each model to give more variety. Also signs should be
on the lower part of the wall at roughly eye height."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | passed | Retry | the film didn't read as film; fire point and pipework not after the photos; a cable reel with no photo |
| 2026-11-15 | 2 | Opus 5.5 (build thread) | passed | Retry 6/8 | fire point's cabinet proportions; film still a frame; IBC side bars past the posts; parts cage goods past its ends; no pipework close-up; stale comments |
| 2026-11-15 | 3 | Opus 5.5 (build thread) | passed | Retry 7/8 | kraft film still read as carton shades; fire point's foot and hood; a faceted handwheel |
| 2026-11-15 | 4 | Opus 5.5 (build thread) | passed | Retry 7/8 | the fire point's window a letterbox; its cabinet a box on a box |
| 2026-11-15 | 5 | Opus 5.5 (build thread) | pending | pending | – (the owner's ruling: past the attempt cap, keep fixing until the critic passes) |

## What changed

- **Three new rack bays, three of each** (`tools/blender/maps/wrapped_racking.py`, `drum_ibc_stack.py`,
  `parts_cage.py`, shared parts in `bay_kit.py`): 2.7 x 3.0 x 0.9 m like `pallet_racking.py`'s, front to -y, so
  PropLayout lays them as it lays the racking (`Lay.TILE`, dark backing half a row in, the three bays taking turns,
  40 m chunks, no shadow). The third bays (the owner's ask for variety): racking with photo 7's capped load and finer
  cartons, two IBC towers side by side topped with empty pallets (photo 2), and photo 4's store with a deck across
  the bay over flattened cartons and totes. The wrapped loads show their film as a broad sheen rising across the face
  (the cartons under it a fifth lighter, so their joints still show through), one or two sharp specular streaks, and
  a pale film cap over the top whose front and side edges bevel down so it bulges over the corners (the purple hooded
  loads filmed over their caps too). 1,324 to 1,454 triangles of the bay's 1,500.
- **Which blocks:** `tools/depot/extras.py` `rack_dress` gives each `dead` piece a `dress` in turn (racking, wrapped
  racking, drums and IBCs, racking, parts cage), the two 108 m strips along the long walls staying racking: 24 of
  Depot's 48 rack blocks. The blocks' boxes are untouched (the map's blocks match the old file's but for `dress`), so
  collision, nav, cover, sight lines and the baked light (its hash covers kind, place and size, not dress) are as
  they were: no rebake.
- **Wall extras** (`depot_extras.py`, the signs' sheet by `depot_signs.py` with cells in `depot_cells.py`): photo 3's
  wall-mounted fire point board (its moulded cabinet as wide as the board at its ears and 32 % of its height,
  tapering down curved haunches to a foot 0.8 of its width, with a smooth bulging front, the lid sunk behind a rim
  between raised ears, and a rounded 0.30 x 0.09 m viewing window in a shallow recess under a moulded visor), a call point, 4 m and 2 m lengths of pipework (every third 4 m length, `pipe_run_b`,
  with a gate valve and its 12-sided handwheel, a drop to a pendant sprinkler head and a junction box with its conduit), and seven safety signs. They are
  `MapData.fixtures` (`dressing.fixtures`, read by `StationDressing.read_fixtures`), drawn by StationFixtures as
  Subway's extras are: one MultiMesh a model, no collider, no shadow; a model may print from its own sheet
  (`StationFixturesConfig.sheets`).
- **Where the extras go** (`extras.py` `fixtures`, written by `build_map.py`): pipework along every hall wall at
  5.6 m (over the shutters' coil boxes, under the rooflights), a length between columns, the end walls' stopping 2 m
  short of the corners under the long walls' runs; fire points hung 0.3 m up, 0.9 m beside a column on an open wall,
  20 m apart along it, then every safety sign at eye height (1.6 m) on the lower wall on the spots left, 6 m from any
  other, in turn (the owner: no high signs over the racking); a "Fire exit, keep clear" sign beside each fire exit's door; a call point
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
- **No cable reel:** none of the photos shows one, and the critic held models to the photos; the fire points and signs
  fill the open wall.
- **Signs only where the wall is open in front:** a sign behind racking at eye height would be hidden, so seven signs
  stand on the open stretches, and the racking walls keep the pipework over them.
- **Pillar signs left out:** a flat sign on the 0.4 m round post would stand off it at its edges; the call point and
  extinguisher are small enough to sit on it.

## Known issues left

- None known. How it looks in play on the owner's cards is play check N16.
