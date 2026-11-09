# DM1 · Depot's plywood walls, crates, containers and doors

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (map models thread, group 1) | – | 5/8 Revise (QA Pass, performance Pass) | modules stretched up to 55 %, doors distorted on other maps, budgets under 95 %, container doors and crate off his photos, low caps squashed, no tests |
| 2026-11-09 | 2 | Opus 5.5 (map models thread, group 1) | – | 5/8 Revise (QA Pass, performance Pass) | door panels out of proportion (mid rail at a fixed height), olive door and khaki crate, lintel piece with pockets, bars broken by painted guides, grain like seams, no perforations, hexagon patches, wiki wording |
| 2026-11-09 | 3 | Opus 5.5 (map models thread, group 1) | | | |

## What changed

The first of Dev 3's map models (owner, 2026-11-09: "begin work on these models in blender"), group 1 of five, built
from William's photos (`art/references/maps/william-2026-11-09/` in the project files: wooden_crate, plywood_wall,
shipping_container, wooden_door). Every model is one vertex-coloured mesh (no textures) made by a script in
`tools/blender/maps/` on the shared `map_kit.py`, drawn by PropDress (MultiMesh) like the CC0 props.

- **Crate** (`crate.py`, 398 of 400 triangles): plywood box on a block pallet (dark fork openings), galvanised edge
  profiles with perforations, clips top and bottom, thin wavering grain streaks, a different tone each face, stencils. Replaces the Kenney box on
  Depot and Woodland; GRID lay in 1.2 x 1.15 x 1.0 m cells (the map's blocks set the footprint). Blocks under 0.85 m
  (the desks) stay boxes (`kind_min_height`).
- **Plywood wall** (`plywood.py`, 236 of 245 a 0.61 m module; 192, 148, 112 for the 1.7, 1 and 0.5 m ones): a sheet
  between half battens, the stud's nails, lens-shaped football patches, skirting, cap (and the rail and filler strip at full height).
  The new RUN lay lays whole modules at the 0.61 m batten pitch, stretched at most 10 % (`run_stretch`) or made up with
  a cut module at the end (never a sliver under a quarter module, `run_min_cut`); `heights` picks the version built nearest each block's height, so caps and rails keep
  their size. Blocks deeper than 0.5 m (the wardrobe) stay boxes (`kind_max_depth`); under 0.3 m, boards.
- **Container** (`container.py`, unit 1,720 of 1,800; the low piece 244 and the lintel piece 236 of 250 (no rail or
  pockets over a port); wall 388 of 400; roof 480 of
  500): corrugated sides (slopes baked darker), a door end after his photos (flat leaves with pressed ribs, rubber
  seals, 12-sided locking bars between split brackets, keepers, handles and retainers in bare galvanised steel), castings, framed forklift pockets, vents. The
  game paints each container (`SiteLook.prop_paint`, one paint a joined row, `_first_joined`) through the instances'
  custom data in `look_vertex.gdshader` (`paint_by_custom`): parts with vertex alpha 0 (`map_kit.bare`) stay steel.
  The new UNIT lay turns the doors to the row's free end; a near-square cut piece lies along the row it joins
  (`unit_square`). SiteDress no longer draws the old frames, battens and chevrons under blocks drawn as props.
- **Door** (`door.py`, leaves 494 of 500, frames 132 to 168 of 175): a two-panel golden-oak leaf with raised fields,
  its mid rail at 0.44 of its height and the handle on it (his photo's proportions), grain, shadow lines, lever, rose,
  keyhole, hinges; frames with linings standing 6 mm into the opening (no plane
  shared with the wall's cut end), moulded architraves on plinth blocks, a head where a wall stands over the opening.
  Three sizes each (Depot's 2.0 x 2.6, the huts' 1.6 x 2.5, The Street's 0.9 x 2.1); DoorView takes the nearest to a
  map's first door, so a leaf stretches little. A frame is as deep as the thinnest wall at its jamb and casts no
  shadow (its wall does); at least 0.1 m deep whatever thin block stands at the jamb.
- **Removed:** the Kenney crate recipe in `tools/props/build_props.py`.
- **Tests** (`test_dm1_map_models.gd`): the run's pitch, stretch and cut module (and every Depot module), the
  versions by height, thin and flat, the doors to the free end, a cut piece along its row and units side by side
  kept along their boxes, a row's paint in custom data with bare steel in the model, the door models by size, the
  frame's depth at a corner and its shadow.

## Decisions

- **Doors are timber, not green** (default, from his photos). His honey oak sits in Beta's orange band, so the oak is
  golden just past it (hue about 49°, saturated, so it reads as wood, not olive) against the pale plywood.
- **Crate wood warmer than the walls'** (his photos' tan, hue about 49° too, less saturated than the doors); the walls
  stay pale birch as in his plywood photos.
- **The crate's proportions follow the map's blocks**, not the photos' 1.5:1: the blocks are cover sized for play.
- **Containers lose the site's chevrons** (default): real containers don't carry them; the paint still sorts them.
- **Depot's frames have no head**: its openings run up to the walls' cap (a head would need a shorter leaf and a
  different opening, a map change); the huts' and The Street's have one.
- **One leaf and frame size a map** (its first door's): every map's doors are one size today.
- **The Box is one paint, not three** (a joined row takes its first block's paint, so a container never shows two).
- **Low modules are short of 95 %**: the budget is a 2.6 m module's; the lower ones carry the same detail per metre.
- **Desks and the wardrobe stay boxes** until group 3's office models.
- **An open door's handle may touch the wall** it swings against (2 cm, not seen at eye height).

## Known issues left

- Tunnel lids (optional in the plan) not made.
- Woodland's plywood huts take the same modules (their walls are plywood blocks); its 0.88 to 1.5 m pieces show a cut
  module.
