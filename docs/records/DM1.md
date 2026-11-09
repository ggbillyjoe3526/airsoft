# DM1 · Depot's plywood walls, crates, containers and doors

**Review:** 4 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (map models thread, group 1) | – | 5/8 Revise (QA Pass, performance Pass) | modules stretched up to 55 %, doors distorted on other maps, budgets under 95 %, container doors and crate off his photos, low caps squashed, no tests |
| 2026-11-09 | 2 | Opus 5.5 (map models thread, group 1) | – | 5/8 Revise (QA Pass, performance Pass) | door panels out of proportion (mid rail at a fixed height), olive door and khaki crate, lintel piece with pockets, bars broken by painted guides, grain like seams, no perforations, hexagon patches, wiki wording |
| 2026-11-09 | 3 | Opus 5.5 (map models thread, group 1) | ✓ | 7/8 Revise | door rails and stiles off his photo's shares, khaki door and crate (hue held at 48° when the rule allows 36°), grain still full-height lines, three holes a profile not a dense row |
| 2026-11-09 | 4 | Opus 5.5 (map models thread, group 1) | ✓ | 7/8, near-miss re-run 8/8 Accept (QA Pass, performance Pass) | re-run: the door fields' tone grid read as zigzags; redrawn as lens bands (`map_kit.band`); QA's advisories (pixel size from both axes, the far row spread over a pixel) applied |

## What changed

The first of Dev 3's map models (owner, 2026-11-09: "begin work on these models in blender"), group 1 of five, built
from William's photos (`art/references/maps/william-2026-11-09/` in the project files: wooden_crate, plywood_wall,
shipping_container, wooden_door). Every model is one vertex-coloured mesh (no textures) made by a script in
`tools/blender/maps/` on the shared `map_kit.py`, drawn by PropDress (MultiMesh) like the CC0 props.

- **Crate** (`crate.py`, 394 of 400 triangles): pale birch plywood box on a block pallet (dark fork openings),
  galvanised edge profiles with a dense row of holes every 4.5 cm (punched by `look_vertex.gdshader`'s
  `perforations` from the strips' UVs, `map_kit.perforated`: two triangles a row, faded to the row's shade where a
  hole is under a pixel), clips top and bottom, soft grain bands that fade in and out inside each face
  (`map_kit.toned`, vertex shades, no lines), a different tone each face, stencils. Replaces the Kenney box on
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
- **Door** (`door.py`, leaves 490 of 500, frames 132 to 168 of 175): a two-panel honey-oak leaf with raised fields,
  its rails and stiles at his photo's shares (top 0.071, mid 0.087 at 0.44, bottom 0.092 of the height; stiles 0.155
  of the width) and the handle on the mid rail, soft upright grain bands on the fields (`map_kit.band`, shared with
  the crate), shadow lines, lever, rose,
  keyhole, hinges; frames with linings standing 6 mm into the opening (no plane
  shared with the wall's cut end), moulded architraves on plinth blocks, a head where a wall stands over the opening.
  Three sizes each (Depot's 2.0 x 2.6, the huts' 1.6 x 2.5, The Street's 0.9 x 2.1); DoorView takes the nearest to a
  map's first door, so a leaf stretches little. A frame is as deep as the thinnest wall at its jamb and casts no
  shadow (its wall does); at least 0.1 m deep whatever thin block stands at the jamb.
- **Removed:** the Kenney crate recipe in `tools/props/build_props.py`.
- **Tests** (`test_dm1_map_models.gd`): the run's pitch, stretch and cut module (and every Depot module), the
  versions by height, thin and flat, the doors to the free end, a cut piece along its row and units side by side
  kept along their boxes, a row's paint in custom data with bare steel in the model, the door models by size, the
  frame's depth at a corner and its shadow, the crate's perforated strips and the props' shader punching them.

## Decisions

- **Doors are timber, not green** (default, from his photos). His honey oak (linear hue 18 to 21°) sits in Beta's
  orange band (test_props.gd: no prop within 20° of a team's hue unless greyed; Beta 15.4°, High contrast's 7 to
  9°), so the oak is moved to 38°, its lightness and saturation kept: honey, stiles darker than panels.
- **Crate wood his photos' pale birch** (linear hue 33 to 37°, moved to 38° the same way); the walls stay pale birch
  as in his plywood photos.
- **The crate's holes are drawn by the shader** (default): a dense row costs two triangles a profile instead of about
  300 more for the crate (290 crates on Depot). The props' one material keeps them; a far crate shows the row's shade.
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
