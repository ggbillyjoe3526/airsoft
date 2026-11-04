# First-person arms

`arms.glb` (glTF binary): the player's own arms in the first-person view, gloved and sleeved, built by
`tools/blender/arms/arms.py` (BL1, 2026-11-04). The game does not draw them yet: the first-person arms are wired in at
the art pass (step 32, `ReplicaView.arms_kind`).

- **Space.** Metres, Blender +Y forward from the eye (at the origin), +Z up. Exported +Y up, as every model here.
- **Skeleton.** `Root`, then each side's `Shoulder`, `UpperArm`, `Forearm`, `Hand`, `Thumb1-3`, `Index1-3`,
  `Middle1-3`, `Ring1-3`, `Pinky1-3` and `Grip` with `_R` or `_L`: the figures' bone names, so their hand poses fit.
- **Mesh.** `Arm_R` and `Arm_L` (38,740 triangles together): the MakeHuman base mesh's arm and hand (CC0,
  `tools/blender/arms/source/`) under a glove and sleeve, skinned to that skeleton.
- **Materials.** `Glove`, `GloveArmour`, `Sleeve`, `SleeveTrim`. Plain colours, no textures.
- **Clip.** `Rifle_Hold`: the right hand round the AEG Rifle's grip with the index finger on the trigger, the left
  cupping its handguard, both elbows bent. The `ReplicaHold` empty is where the AEG Rifle's origin sits in that pose.
  The pose is solved against the rifle's mesh, and `arms.py` stops without writing if any face of the arms passes
  into the rifle; re-run it whenever `aeg.glb` changes.
- **Budget.** `docs/CC0_ASSETS.md` › Size limits: first-person arms ≤ 40,000 triangles, ≤ 4 materials.
