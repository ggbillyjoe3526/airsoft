# Map models

Blender build scripts for the maps' own models (Dev 3), each writing one vertex-coloured prop to
`assets/models/props/` the way the Kenney props are (one `Prop` material, palette colours linear; a lamp's lens keeps a
material of its own). `mapkit.py` holds the shared palette, the vertex-colour bake, the export and the triangle report
for the hall shell (DH1); `prop.py` does the same for the racking and small props (RK1), painting by palette name with
a foot-to-top gradient (`render_prop.py` renders a built prop from labelled angles); `woodkit.py` holds Woodland's
shared parts (bark, logs, split ends, leaf clumps, fronds) and its colours, each checked off the team hues as the tests
measure them (WG2).

| Script | Writes | Drawn as |
|---|---|---|
| `hall_wall.py` | `hall_wall.glb`, `hall_shutter.glb`, `hall_exit.glb` | Depot's 8 m hall walls, bay by bay (`PropDressConfig.Lay.BAY`) |
| `steel_pillar.py` | `pillar.glb` | Depot's pillars (fitted to the block) |
| `camo_net.py` | `camo_net.glb` | Depot's net walls, a 2 m section a cell |
| `roof_truss.py` | `roof_truss.glb`, `roof_lamp.glb` | Depot's roof bays and lamps (`RoofView`) |
| `pallet_racking.py` | `pallet_racking.glb`, `_b`, `_c` | Depot's tall racks, three bays taking turns (`PropDressConfig.variants`) |
| `kit_rack.py` | `kit_rack.glb` | The Range's kit rack (its block names it) |
| `steel_drum.py`, `pallet.py` | `steel_drum.glb`, `pallet.glb` | Depot's drum blocks, nine stacks on a pallet (CLUSTER) |
| `plastic_barrel.py` | `plastic_barrel.glb` | Depot's barrel blocks, two a block (ROW) |
| `sofa.py`, `office_desk.py`, `steel_locker.py` | `sofa.glb`, `office_desk.glb`, `steel_locker.glb` | The Lounge's sofa, the Offices' desks and lockers (fitted) |
| `fern.py`, `bush.py` | `fern.glb`, `bush.glb` | Woodland's ferns and bushes (`BushView`), stretched to each plant |
| `fallen_log.py` | `fallen_log_5.glb`, `_6.glb`, `_8.glb` | Woodland's fallen logs, the nearest length (`PropDressConfig.Lay.GROUND`) |
| `root_plate.py` | `root_plate.glb` | Woodland's wind-thrown trees (`Lay.GROUND`) |
| `cordwood.py` | `cordwood.glb`, `_b`, `_c`, `boards.glb` | Woodland's woodpiles, a 2 m section a cell, the three mixed (`Lay.GRID`, `variants`); B site's boards (`Lay.GROUND`) |
| `sawbench.py` | `sawbench.glb` | Woodland's B site saw bench (`Lay.GROUND`) |
| `earth_bank.py` | `earth_bank.glb` | The earth under a grounded prop where the ground falls away |
| `log_tunnel.py` | `log_tunnel_side.glb`, `log_tunnel_roof.glb`, `log_tunnel_mouth.glb`, `log_tunnel_cap.glb` | Woodland's crouch tunnels, a 1 m hollow-log section a block (`Lay.SIDE`, `Lay.LINED`; a run's end sections the mouth) |
| `culvert.py` | `culvert_wall.glb`, `culvert_kerb.glb` | Woodland's culvert under the road |
| `pickup.py` | `pickup.glb` | Woodland's pickup wreck (grounded) |
| `tyre.py` | `tractor_tyre.glb`, `tractor_tyre_stack.glb` | Woodland's tyre stacks (grounded) |
| `campfire.py`, `lantern.py` | `campfire.glb`, `lantern.glb`, `lantern_post.glb`, `lantern_chain.glb` | Woodland's fires and lanterns (`LightFixtures`, no collider) |
| `pine.py` | `pine_young.glb`, `pine_grown.glb`, `pine_old.glb` (each with its `_crown`) | Woodland's pines, the age by the tree's height (`PropDressConfig.Lay.TREE`) |
| `oak.py` | `oak.glb`, `oak_crown.glb` | Woodland's hand-placed oaks (TREE) |
| `birch.py` | `birch.glb`, `birch_crown.glb` | Woodland's birches (TREE) |
| `spruce.py` | `spruce.glb` | Woodland's thickets, a spruce a 1.5 m cell (GRID) |
| `far_tree.py` | `forest_tree.glb`, `skyline/treeline.glb` | The wood past Woodland's fence (`WoodsConfig.forest_model`) and the skyline's treeline band (`SkylineConfig.treeline_model`) |

The trees share `treekit.py`: stems, limbs, foliage clumps and spruce tiers with crown-lit normals, and the build gates
(budget, no team hue, the trunk inside its foot radius, the crown only over the clearance outside it). A tree's trunk
and crown are written apart (`export(..., crown=True)`): the game stretches the trunk to its box and scales the
crown evenly over it.

Run each with Blender 5.x or pip's `bpy` (`pip install bpy==5.2.3`): `python3 -I tools/blender/maps/<script>.py <repo
root>`, then `godot --headless --path . --import`. Pictures for review: `tools/prop_pictures.gd` (a model alone) and
`tools/hall_pictures.gd` (Depot), both under xvfb; `tools/eye_pictures.gd` for a field (`night` lights its fires and
lanterns). Records: `docs/records/DH1.md`, `docs/records/RK1.md` (RK1's scripts run as `python3
tools/blender/maps/<script>.py`), `docs/records/WG2.md`, `docs/records/WG4.md` (`weathering.py`: WG4's noise and
repaint helpers), `docs/records/WT1.md`. Dev only: tools/ never ships.
