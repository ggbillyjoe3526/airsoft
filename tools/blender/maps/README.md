# Map models

Blender build scripts for the maps' own models (Dev 3), each writing one vertex-coloured prop to
`assets/models/props/` the way the Kenney props are (one `Prop` material, palette colours linear; a lamp's lens keeps a
material of its own). `mapkit.py` holds the shared palette, the vertex-colour bake, the export and the triangle report.

| Script | Writes | Drawn as |
|---|---|---|
| `hall_wall.py` | `hall_wall.glb`, `hall_shutter.glb`, `hall_exit.glb` | Depot's 8 m hall walls, bay by bay (`PropDressConfig.Lay.BAY`) |
| `steel_pillar.py` | `pillar.glb` | Depot's pillars (fitted to the block) |
| `camo_net.py` | `camo_net.glb` | Depot's net walls, a 2 m section a cell |
| `roof_truss.py` | `roof_truss.glb`, `roof_lamp.glb` | Depot's roof bays and lamps (`RoofView`) |

Run each with Blender 5.x or pip's `bpy` (`pip install bpy==5.2.3`): `python3 -I tools/blender/maps/<script>.py <repo
root>`, then `godot --headless --path . --import`. Pictures for review: `tools/prop_pictures.gd` (a model alone) and
`tools/hall_pictures.gd` (Depot), both under xvfb. Records: `docs/records/DH1.md`. Dev only: tools/ never ships.
