# DR2 · Depot's CC0 dress

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | prop (12), site dress, DD1, map, bake, budget and session tests pass; full suite on CI | Retry 7/8 | a slot behind racks against a wall or rack (seen through, stops BBs); QA: a model there but unloadable folded its boxes; performance: the shelving was one hall-wide draw |
| 2026-10-31 | 2 | thread | prop (14), DR2 QA (3), site dress, DD1, map, bake, budget, hall, noisy prop and session tests pass | – | – |

## Goal

The owner (2026-10-31, approving concept 3): "Dress it with free CC0 assets." Fourth of four pull requests for the new
Depot: DR1 the map, DO1 doors, AB1 two flags (all merged), DR2 the CC0 dress; then screenshots and a playtest list.

## Approach

- **Models.** Five Kenney models (CC0): the Survival Kit's barrel (as two props, barrel and drum), the Retro Urban
  pallet, the Furniture Kit's lounge sofa and the Mini Market's stocked shelf. `tools/props/build_props.py` (dev
  only) reads them from the library's GitHub mirror (kenney.nl is blocked in the cloud) and writes
  `assets/models/props/*.glb`: the source's triangles and normals with a colour on every vertex (linear, as glTF
  keeps them) in place of its texture or materials, each part (a palette family, a node, a material) in the recipe's
  colour with the source's shade kept. One material draws them all; no texture ships (148 KB for the five).
- **Where they stand** (`PropLayout`, pure, seeded by the map's dressing seed). Drum blocks: four drums on a pallet;
  barrel blocks: two barrels side by side; the sofa stretched to its block, facing the field's middle; tall racks
  (3 m; the 0.15 m shelf boards stay boards): every face 1.5 m or longer lined with a row of shelving as tall as the
  rack, up to 0.9 m deep (half the rack's depth at most), facing out; a face wholly against another block (the
  perimeter racks' backs on the wall, faces inside overlapping racks) gets none, and the rows beside it run to its
  corner (`PropLayout.lining`). Every prop stays inside its block's box (tested
  vertex by vertex), so collision, cover, sight and the nav grid are the blocks' as before.
- **The boxes** (`SiteSurface.core_of`, `MapLevel`). A drum's, barrel's or sofa's box folds to its middle (its tiles
  stay, so the bake still fits) and leaves the baked shadow caster; the props cast their own. A rack's box is drawn
  half a row inside each lined face and flush with each unlined one in a dark backing (`backing` finish), so the
  shelving's fronts stand proud and a rack's whole footprint is shelving or backing: nothing is seen through a rack
  that would stop a BB (tested point by point along every side).
- **Loading.** A kind is dressed only when its model's mesh actually loads (`PropDressConfig.mesh_of`, loaded once a
  path); a missing or broken model leaves its blocks as boxes, with one warning.
- **Drawing** (`PropDress`, built by SiteDress so the match, the map cards and the range get it): one MultiMesh a
  model, the shelving one a 20 m chunk so it culls off screen and far chunks take the simpler mesh Godot's import
  generates (44 triangles for 436; the Mesh detail step sets the threshold). On Depot 358 shelves in 24 chunks, 36
  drums, 26 barrels, 9 pallets and the sofa: 182,516 triangles at full detail (85 % shelving), 28 draw calls at most,
  instance shades varied ±6 %, the material in the prewarm through `SiteDress.materials()`.
  Drums, barrels, pallets and the sofa cast shadows; the shelving doesn't, its rack's backing box still does.
- **Data.** `PropDressConfig` (SiteLook's `props`): models, each kind's prop and lay, the cluster cell, pallet height,
  row depth, the smallest lined face, the backing's top, the shade jitter and the material.

## Defaults taken

- Colours off both teams' hues (the linear-hue test the bushes use): raspberry steel barrels, teal fibre drums with
  dark hoops, bleached pallets, the plum sofa, green racking with dull cartons and cream boxes. SiteLook's drum and
  barrel paints follow; MapStyle's stay (they feed the bake's hash).
- Round props turn by random quarter turns only, so the model's own bounds, and so the box, still hold them.
- A round prop in a square block leaves the block's corners empty but solid to BBs (up to about 10 cm): noted in
  KNOWN_ISSUES rather than reshaping the colliders.
- Crates, plywood, containers, pillars, netting and walls keep DD1's site look; the owner's own models replace all of
  it later (Blender at Beta).

## Checks

- Locally: `tests/unit/test_props.gd` (12) and the site dress, DD1, map level, bake, budget guard, play session,
  skyline, flag and noisy prop tests pass; gdlint passes. CI runs the full suite and the match guards (no rule or
  collider changed).
- For the owner to play: whether the shelving reads as a solid rack from every lane; whether the drums and barrels
  read as cover at a glance; whether the colours sit well in the hall; frame rate on Low with the shelving's shadows.
