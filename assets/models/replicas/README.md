# Replica models

A replica's model as `<replica id>.glb` (glTF binary): the AEG's (BL1, reworked in BL3, from `tools/blender/replicas/aeg.py`), the GBB Pistol's (BL2, from `gbb.py`), the Sniper Rifle's (BL5, from `sniper.py`), the Compact SMG's (CS2, from `smg.py`) and the Cyber Pistol's
(M101, RM1, rebuilt in BL6 from `cyber.py`), with their fittable parts beside them in `../replicaParts/<replica id>.glb`. The browser game drew each
replica from its file in the hands, on the menus' pictures and on the figures, and so does the Godot game. The Cyber
Pistol's `RearSight` and `FrontSight` empties were added to its file for CP1 (2026-10-19), at the browser game's
`ironSight` marks. A replica with no model yet can name a stand-in in its config (`ReplicaConfig.model`), as the Compact SMG
named the AEG until its own `smg.glb` (CS1, CS2). Objects, materials, space and budget:
[docs/CC0_ASSETS.md](../../../docs/CC0_ASSETS.md) › Replica models. Record every model in
[docs/ASSETS.md](../../../docs/ASSETS.md).

`aeg_wear.png` and `pistol_wear.png` are those replicas' wear masks (RW1, 2026-11-10: faint scratches, rubbed edges,
dirt in the recesses), baked by `tools/blender/replicas/wear.py` into their glb, extracted here by Godot's import and
read by `game/play/replica_paint.gd` (docs/CC0_ASSETS.md › Replica models › Wear). The Compact SMG has `smg_wear.png`
too; the Cyber Pistol and the Sniper Rifle have none.

Every face of the hands' meshes says what it is made of in its vertex colours (MQ1, 2026-11-12: steel, aluminium,
polymer, wood; `tools/blender/replicas/surface.py`), and `game/play/replica_paint.gd` draws the paint on that surface
(docs/CC0_ASSETS.md › Replica models › Surfaces). The figures' copies carry none.
