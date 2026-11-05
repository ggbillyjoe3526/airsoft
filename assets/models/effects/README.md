# Effect models

`bb.glb`: every BB in flight (BM1), built by `tools/blender/effects/bb.py`. One smooth ball, 1 m across and centred,
because `game/play/bb_view.gd` draws it at `EffectsConfig.bb_size` (`bb_model` names the file). The game draws it in
its own materials (white with a rim, or glowing green), so the file's material is a placeholder. Imported with no
LODs, shadow meshes or tangents: a BB casts no shadow and is never lit by a normal map. Record every file in
[docs/ASSETS.md](../../../docs/ASSETS.md).
