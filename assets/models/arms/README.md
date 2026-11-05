# First-person arms

`arms.glb` (glTF binary): your own arms in the first-person view, in coyote gloves and sleeves, holding the replica in
hand (BL4, 2026-11-05). Built by `tools/blender/arms/arms.py` (`python3 -I tools/blender/arms/arms.py .`, pip
`bpy==5.2.3`); drawn by `game/play/arms_view.gd` (ArmsView, under ReplicaView).

- **Space.** Metres, Blender +Y forward from the eye (at the origin), +Z up; exported +Y up, as every model here, so
  in Godot the eye looks along -z.
- **Skeleton.** `Arms`: each side's `Shoulder`, `UpperArm`, `Forearm`, `Hand`, `Thumb1-3`, `Index1-3`, `Middle1-3`,
  `Ring1-3`, `Pinky1-3` and `Grip` with `_R` or `_L`, the figures' bone names.
- **Mesh.** `Arm_R` and `Arm_L` (39,646 triangles together): the MakeHuman base mesh's arm and hand (CC0,
  `tools/blender/arms/source/`) under a glove (skin + 1.1 mm, `glove.py`) with a moulded knuckle guard, padded
  fingers and thumb, a suede palm patch, a cuff and wrist strap, and a sleeve rolled over the cuff with a banded hem.
- **Materials.** `Glove` (coyote), `GloveArmour` (guard, pads, strap, patch), `Sleeve`, `SleeveTrim`. Plain colours,
  no textures. A robot's arms are recoloured in game (ViewModelConfig.robot_arms).
- **Holds.** One per replica: a clip `<id>_Hold` (`aeg`, `pistol`, `cyber`, `sniper`) posing both arms, and an empty
  `Hold_<id>` where that replica's origin sits in it (at ViewModelConfig.hip). In game the arms ride the replica's
  node with that empty on its origin, so they follow its sway, kick, cant and drop.
  - Rifles (`aeg`, `sniper`): the right hand round the pistol grip, index on the trigger, thumb round the back; the
    left palm under the handguard, fingers up its right side.
  - Pistols (`pistol`, `cyber`): held in the right hand alone, the left arm lowered (and hidden in game,
    ViewModelConfig.one_hand).
- **Solving.** `pose.py` places each hand on the replica's mesh (knuckle line, palm seated to contact, fingers curled
  until they touch, the index onto the trigger) and bends each elbow to keep the wrist straight; `arms.py` stops
  without writing if any face of the arms passes into a replica. Re-run it whenever a replica's model changes.
- **Not yet.** No arm clips for firing or reloading: the replica's own clips move its parts as before.
- **Budget.** `docs/CC0_ASSETS.md` › Size limits: first-person arms ≤ 40,000 triangles, ≤ 4 materials.
