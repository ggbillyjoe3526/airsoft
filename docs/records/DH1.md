# DH1 · Depot's hall shell: walls, pillars, nets, roof, lamps and floor from the owner's photos (Dev)

**Review:** critic Accept 8/8 · qa Pass · performance Pass (follow-up: critic Accept 7/8 · qa Pass · performance Pass)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | build thread | see Verified; QA Pass, performance Pass | Reject 6/8 | fidelity to the photos (fire exit, net, truss depth, rooflights), shutter gaps, cladding shimmer, floor aggregate |
| 2026-11-09 | 1, fix round 1 | build thread | see Fix rounds | Retry 7/8 | a see-through slit where two net sections meet |
| 2026-11-09 | 1, fix round 2 | build thread | see Fix rounds | Accept 8/8 | – |

## Goal

Dev 3's map models, group 2 (`art/depot-range-model-list.md` in the project files): Depot's hall shell modelled in
Blender from the owner's reference photos (`references/maps/william-2026-11-09/`): the hall wall bay with a roller
shutter bay and a fire exit bay, the steel pillar, the roof truss bay, the high-bay lamp, the camouflage net wall, and
the floor's concrete. Each model fills its block's box and never goes past it; the 65 m Chrono hall sight line stays
open.

## Approach

- **Models** (`tools/blender/maps/`, one vertex-coloured mesh each, exported like the Kenney props through the new
  `mapkit.py`): `hall_wall.py` (three 8 m bays: plain, shutter, fire exit; 1,568, 2,142 and 2,186 triangles of 2,000,
  4,000 and 4,000), `steel_pillar.py` (1,116 of 1,200), `camo_net.py` (a 2 m section, 1,452 of 1,500),
  `roof_truss.py` (the 8 x 18 m roof bay, 2,256 of 4,000; the lamp, 368 of 400, its lens a material of its own).
- **Floor** (`tools/textures/concrete_floor.py`): a seeded, tiling 2K colour and normal map of floated concrete with
  exposed aggregate. `SiteLook.slab_grain` (0.75) draws it on the clean look; the plywood photo still waits on `grit`.
- **Walls as bays** (`PropDressConfig.Lay.BAY`, `PropLayout._bays`): a wall 6 m or taller is cut into cells on a world
  grid (`bay_pitch` 8 m from `bay_anchor`), so the long walls' columns stand under the roof's trusses (every
  `RoofConfig.truss_step` m from x 0). Each bay faces the field's middle. A feature bay (shutter, exit, taken in turn)
  goes in a whole cell with nothing within 2 m of its face below 3 m (`bay_open`), at most two a wall, never side by
  side. Depot gets two shutters and one fire exit. Lower walls (the Range, The Street) keep their boxes.
- **Pillars** are fitted to their box (FIT); **nets** lay a section every 2 m (GRID).
- **Roof** (`RoofView`): one bay model a truss line and cell (`bay_placings` on `bay_lines`, the truss lines plus one
  past each end so the sheet reaches the end walls; cells about `bay_span` 18 m across), two truss lines a MultiMesh
  (`bay_chunk`) so far ones cull; the ceiling box sits 1 cm over the bays' sheet. Lamps are the high-bay model hanging
  from the roof, the `Lens` surface glowing, the body in the shared light, each moved at most `lamp_clear` (0.4 m) off a
  truss line so none hangs inside a truss (7 of Depot's 93).
- **Walls and nets** are chunked like Woodland's many props (`PropDressConfig.spread_models`, 40 m squares) so the
  far side of the hall culls; a wall drawn as bays drops the site dress's coping (its own eaves cap it). Without the models,
  the old beams and panels draw as before. Nothing in the roof casts a shadow.
- **Tools:** `tools/prop_pictures.gd` (a prop alone, three views) and `tools/hall_pictures.gd` (Depot in a frozen
  session, square on to each feature, pillar, net, the roof and the hall), both under xvfb.

## Decisions and defaults

- **The floor carries texture** although the look's surfaces are otherwise clean (`docs/ART.md`): the owner asked for
  the floor from his photos. Default: aggregate, cloud, speckle, a few hairline cracks and faint stains at 0.75 of the
  slab's mix. `SiteLook.slab_grain = 0` makes it clean again. As every graphic is an engine feature (DECISIONS,
  2026-10-04), it is the slab set of every map's concrete (floors, the dock), not Depot's alone.
- **Budgets:** the owner's list gives a 6 m wall bay 1,500 triangles; the hall's bays are 8 m (the trusses' step), so
  2,000 at the same rate a metre. The plain bay sits at 78 % of it: its cladding ribs went from 32 to 24 a bay and
  half as deep, as the finer ribs shimmered at range.
- **The roof bay is at 56 % of its budget**, not 95 %: about 56 bays are on screen at once from the hall's middle, so
  each triangle counts about 56 times. The wall bays, pillar, net and lamp are at 92 to 96 %.
- **Colours** are the look's palette: crimson columns and trusses (the old trusses' colour), cream cladding, violet
  roof sheet with lilac rooflights, a teal sprinkler main, a green exit sign, yellow guard posts and hazard bands.
- **Feature bays**: two shutters and one exit came out on Depot, placed by the open-front rule; more need clear floor.

## Verified

- `tests/unit/test_dh1_hall_shell.gd`: every hall wall drawn as bays with the long walls' columns on truss lines; the
  Range's and The Street's walls keep their boxes; features at most two a wall, never side by side, their fronts open,
  each kind there; every bay faces the field; one roof bay a truss line and cell, all within 2 m under the roof,
  tops at its underside, reaching both end walls; the lamp has one glowing surface, hangs above 5.5 m and clear of
  the trusses; the slab set loads on the clean look
  and `slab_luma` is its file's mean; every model within its budget.
- `test_props` (the boxes a dressed block hides now include the hall shell's), `test_depot_hall` (the roof's four
  materials), `test_look` (the plywood photo still unloaded).
- Pictures rendered in the game (Forward+, lavapipe) of every model alone and in Depot, posted to the owner.
- `tools/check.sh`: see the pull request.

## Fix rounds

- A test found the lamp's lens drawn as the body: `mapkit.bake_vertex_colours` cleared the material slots after
  setting the faces' indices, which put every face back on slot 0. The faces' slots are now set after.

- Critic, attempt 1 (Reject 6/8), and what changed:
  - Fire exit squat: the pair is now two 0.68 m leaves 2.22 m tall (0.65 wide to high with the frame, as the photos),
    the lintel to the blockwork's top.
  - Shutter: the coil box now runs from the lap out past the low cladding's ends, so no gap shows beside it.
  - Net: the leaves are now the leaf-cut net's zigzag rows (13 cm apart, 14 teeth a row, the mesh dark through the
    slits), muted greens; the mesh hangs 15 mm behind them. The photos' 8 cm rows would need about twice the budget.
  - Roof: the truss is 1.5 m deep (a twelfth of its span), the rooflights a fifth of the roof.
  - Cladding: shallower ribs on a 333 mm profile (the shimmer).
  - Floor: an exposed-aggregate layer, 1 to 3 cm pebbles all over, as the photos.
  - Corner bays squashed to 81 % (the 109 m walls end 6.5 m past the last truss line): kept; the columns stay under
    the trusses.
- Critic, fix round 1 (Retry 7/8): a slit where two net sections met. GRID turned each section half a turn at random,
  so neighbours met with different folds; `PropDressConfig.grid_unturned` now lays the net's sections all one way.
- QA (Pass) and performance (Pass) advisories taken: the roof's bare ends, lamps inside trusses, the coping over the
  bays, the walls' chunking. Not taken: no shadow off the wall bays (Low has no sun shadows; High's look needs them).

## Follow-up: solid from outside (after FS1, 2026-11-09)

FS1 (#264) added `tests/unit/test_model_faces.gd` after the owner saw the sky through an inside-out water tower. Run on
these models: the pillar and the lamp are solid all round; the wall bays (2 % from the hall's side: thin trim edge-on)
and the roof bay (from below) are solid from where they are seen. The net was open over its top and at its ends
(11 % of rays met a face turned away): from a crate's top, or past a net wall's end, you could see through it. The
net now closes its dark mesh over the top and across each end (40 triangles, 1,492 of 1,500), and
`test_the_pillar_the_net_and_the_lamp_are_solid_from_outside` holds the three to FS1's 2 %. FS1 changed no shared
build code these models use (`hardsurface.py` is as it was), so the other models rebuild byte for byte the same.

## Outstanding

- How the floor's texture, the roof's busyness and the frame rate feel in play: `docs/PLAYTEST.md` › Depot's hall
  shell (DH1).
