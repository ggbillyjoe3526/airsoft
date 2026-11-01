# ST2 · The Street's CC0 dress

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | thread | see Checks | Retry 7/8 | ST1's changelog note still called the props blocks; no ST2 note |
| 2026-11-01 | 2 | thread | see Checks | Accept 8/8 | – |

## Goal

The second half of the owner's ask for The Street (2026-11-01: "add to the game with CC0 assets … with new art
direction applied"): its cars, vans, lorries, bins, skips, lamps, trees and the House's furniture drawn as CC0 models in
the look's palette, in the boxes ST1 gave them, so cover and collision are unchanged.

## Approach

- **Models.** 23 Kenney models (Car Kit, Furniture Kit, Retro Urban, City Kit Roads; CC0) recoloured by
  `tools/props/build_props.py` into `assets/models/props/`. A new `paint` parts mode splits a vehicle's colour map into
  its paintwork (any saturated pixel), pale glass and chrome, dark tyres and grey trim, so each body is repainted over
  the source's orange, blue or green while the windows and wheels read.
- **The map names them.** `tools/street/build_map.py` gives each car, van, lorry, bin, skip, lamp, tree and House
  furniture block a `dress` (MapData.Block.dress, as Woodland's), the vehicle or bin in its block's own palette colour
  (`car_{paint}`), so the map's colours are unchanged where a prop stands.
- **Config.** `PropDressConfig.models` lists them; bins and kitchen units are laid in a grid (two bins a block, a
  cupboard about every 0.6 m); the rest are fitted to their box.

## Decisions

- None needing the owner.

## Defaults taken

- The lilac car and crimson lorry stand in for ST1's violet ones: violet read as Alpha's blue under the sky light.
- The House's settees are teal: the Depot sofa's violet read as Alpha's blue indoors and crimson as Beta's red; the
  units' top timber (steel and umber read navy indoors).
- Vehicles' glass is pale sea-green: a pale blue at full light read as Alpha's hue (test_props).
- Railings, fences, hedges, kiosks, the bus shelter and the roadworks stay blocks: a railing drawn as bars would show
  gaps a BB can't pass (KNOWN_ISSUES).

## Checks

- `test_props` (a new Street test: every named prop loads, sits inside its block, one car a car block, two bins a bin
  block), `test_st2_qa` (QA: one mesh and surface a model, a fitted prop fills its box's footprint and height),
  `test_street`, `test_st1_qa`, `test_look`.
- Performance (smoke match on The Street, patched): +25 nodes, +5.4 % draws, no orphans; the dress is 107k triangles
  in 24 MultiMeshes, the lightest dressed map (Depot 183k, Woodland 458k). If Low runs short, chunk the vehicles so
  they cull first.

## Known issues left

- Railings and the rest above stay blocks (KNOWN_ISSUES).

## Owner should test

- The parked cars, vans and lorries as cover: what you see should be what stops a BB.
- No vehicle or settee reads as a team's colour by day or under the lamps at night: the yellow cars in shade, the
  crimson lorry far off, steel bins and lamp posts (navy-looking outdoors).
- The skip and the 3.2 m settee, stretched to their boxes: do they look right?
