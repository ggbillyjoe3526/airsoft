# Replica models

A replica's model as `<replica id>.glb` (glTF binary): the AEG's (BL1, reworked in BL3, from `tools/blender/replicas/aeg.py`), the GBB Pistol's (BL2, from `gbb.py`), the Sniper Rifle's (BL5, from `sniper.py`) and the Cyber Pistol's
(M101, RM1, rebuilt in BL6 from `cyber.py`), with their fittable parts beside them in `../replicaParts/<replica id>.glb`. The browser game drew each
replica from its file in the hands, on the menus' pictures and on the figures, and so does the Godot game. The Cyber
Pistol's `RearSight` and `FrontSight` empties were added to its file for CP1 (2026-10-19), at the browser game's
`ironSight` marks. A replica with no model yet names a stand-in in its config (`ReplicaConfig.model`): the Compact SMG
(CS1) is drawn, held and pictured as the AEG until its own `smg.glb`. Objects, materials, space and budget:
[docs/CC0_ASSETS.md](../../../docs/CC0_ASSETS.md) › Replica models. Record every model in
[docs/ASSETS.md](../../../docs/ASSETS.md).
