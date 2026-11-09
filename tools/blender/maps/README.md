# Map models

Blender build scripts for the maps' own models (Dev 3), each writing one vertex-coloured prop to
`assets/models/props/` the way the Kenney props are (one `Prop` material, palette colours linear; a lamp's lens keeps a
material of its own). `mapkit.py` holds the shared palette, the vertex-colour bake, the export and the triangle report
for the hall shell (DH1); `prop.py` does the same for the racking and small props (RK1), painting by palette name with
a foot-to-top gradient (`render_prop.py` renders a built prop from labelled angles); `woodkit.py` holds the Woodland
scripts' timber paints, logs, boards and beams, and their blocks read from `data/maps/woodland.json` (rerun a Woodland
script after `tools/woodland/build_map.py`).

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
| `palisade.py` | `palisade.glb`, `palisade_rail.glb` | Woodland's fences, stake by stake (`PropDressConfig.Lay.STAKES`) |
| `watch_tower.py` | `watch_tower.glb` | Woodland's watch tower, one model over its blocks (`Lay.SET`) |
| `footbridge.py` | `footbridge.glb` | Woodland's North bridge (`Lay.SET`) |
| `sawmill_shed.py` | `sawmill_shed.glb` | Woodland's Sawmill shed (`Lay.SET`) |
| `hut_roof.py` | `hut_roof.glb`, `hut_roof_long.glb` | Woodland's hut roofs (fitted to the block) |

Run each with Blender 5.x or pip's `bpy` (`pip install bpy==5.2.3`): `python3 -I tools/blender/maps/<script>.py <repo
root>`, then `godot --headless --path . --import`. Pictures for review: `tools/prop_pictures.gd` (a model alone),
`tools/hall_pictures.gd` (Depot) and `tools/woodland_pictures.gd` (Woodland), all under xvfb. Records:
`docs/records/DH1.md`, `docs/records/RK1.md` (RK1's scripts run as `python3 tools/blender/maps/<script>.py`),
`docs/records/WG3.md`. Dev only: tools/ never ships.
