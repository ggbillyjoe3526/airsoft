# DM1 · Depot's plywood walls, crates, containers and doors

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (map models thread, group 1) | – | – | – |

## What changed

The first of Dev 3's map models (owner, 2026-11-09: "begin work on these models in blender"), group 1 of five, built
from William's photos (`art/references/maps/william-2026-11-09/` in the project files: wooden_crate, plywood_wall,
shipping_container, wooden_door). Every model is one vertex-coloured mesh (no textures) made by a script in
`tools/blender/maps/` on the shared `map_kit.py`, drawn by PropDress (MultiMesh) like the CC0 props.

- **Crate** (`crate.py`, 372 of 400 triangles): replaces the Kenney box on Depot and Woodland; GRID lay in
  1.2 x 1.15 x 1.0 m cells. Blocks under 0.85 m (the desks) stay boxes (`kind_min_height`).
- **Plywood wall** (`plywood.py`, 392 and 260 of 490): a 1.22 m module laid end to end by the new RUN lay
  (`run_lengths`), stretched to each wall's height and thickness; under 1.5 m the low module (sills, lintels). Blocks
  deeper than 0.5 m (the wardrobe) stay boxes (`kind_max_depth`).
- **Container** (`container.py`, 1,6xx of 1,800; low 196 of 250; wall 372 of 400; roof 480 of 500): painted white,
  tinted per container by `SiteLook.prop_paint` (the piece's paint, one per joined row, `_first_joined`). The new UNIT
  lay turns the door end to the row's free end; thin blocks take the wall, flat ones the roof, low ones the welded
  piece. SiteDress no longer draws the old frames, battens and chevrons under blocks drawn as props.
- **Door** (`door.py`, leaf 472 of 500, frame 192 of 200): DoorView draws the leaf model (its body a 1 m cube it
  scales per leaf) and one frame per door stretched to the opening and the wall; `door_leaf.gdshader` lights each
  face from its own side as before. Falls back to the box if the model won't load.
- **Removed:** the Kenney crate recipe in `tools/props/build_props.py`.

## Decisions

- **Doors are timber, not green** (default, from his photos): darker greyed oak so a door still reads against the
  pale plywood.
- **Wood tones greyed** below the team-hue line (`FieldChecks.reads_as_team`), so no crate or wall reads as Beta's
  orange.
- **Containers lose the site's chevrons** (default): real containers don't carry them; the paint still sorts them.
- **Corrugation baked darker on the slopes** (0.8) so it reads under the hall's soft light.
- **Desks and the wardrobe stay boxes** until group 3's office models.
- **An open door's handle may touch the wall** it swings against (2 cm, not seen at eye height).

## Known issues left

- Tunnel lids (optional in the plan) not made.
