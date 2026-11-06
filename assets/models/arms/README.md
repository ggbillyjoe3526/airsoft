# First-person arms

`arms.glb` (glTF binary): your own arms in the first-person view, in dark olive gloves and sleeves, holding the replica in
hand (BL4, 2026-11-05). Built by `tools/blender/arms/arms.py` (`python3 -I tools/blender/arms/arms.py .`, pip
`bpy==5.2.3`); drawn by `game/play/arms_view.gd` (ArmsView, under ReplicaView).

- **Space.** Metres, Blender +Y forward from the eye (at the origin), +Z up; exported +Y up, as every model here, so
  in Godot the eye looks along -z.
- **Skeleton.** `Arms`: each side's `Shoulder`, `UpperArm`, `Forearm`, `Hand`, `Thumb1-3`, `Index1-3`, `Middle1-3`,
  `Ring1-3`, `Pinky1-3` and `Grip` with `_R` or `_L`, the figures' bone names.
- **Mesh.** `Arm_R` and `Arm_L` (38,900 triangles together): the MakeHuman base mesh's arm and hand (CC0,
  `tools/blender/arms/source/`) under a glove (skin + 1.1 mm, `glove.py`, raised over the hand's forms: the web
  muscle, the thumb's and index finger's bones, the finger joints, with a crease across each) with one moulded knuckle
  shell over the four knuckles (domed, with a padded rim), a round pad on each finger's first section, a suede palm
  patch, a
  cuff and wrist strap, and a sleeve rolled over the cuff with a banded hem, ending 13 cm above the elbow (the view
  never shows the shoulder).
- **Materials.** `Glove` (dark olive-brown), `GloveArmour` (guard, pads, strap, patch), `Sleeve`, `SleeveTrim`; each
  with the woven normal map `arms_ArmsWeave.png` (256 px, `fabric.py`) over its own UVs; otherwise plain
  colours. A robot's arms are recoloured in game (ViewModelConfig.robot_arms).
- **Holds.** One per replica and bomb: a clip `<id>_Hold` (`aeg`, `pistol`, `cyber`, `sniper`, `smoke`, `flash`)
  posing both arms, and an empty `Hold_<id>` where that replica's origin sits in it (at ViewModelConfig.hip). In game the arms ride the replica's
  node with that empty on its origin, so they follow its sway, kick, cant and drop.
  - The AEG Rifle: the right hand high on the pistol grip, the little finger round its foot, index on the trigger,
    thumb wrapped round the grip's left side; the left hand under the handguard's middle, its forearm rising to it from below, fingers resting on its right
    side (not over its top), thumb along its left side.
  - Pistols (`pistol`, `cyber`): held high in the right hand alone, the web of the hand on the back strap under the
    beavertail, the fingers closed up under the trigger guard with the little finger on the grip, the thumb forward
    along the frame's left side under the slide; the left arm lowered (and hidden in
    game, ViewModelConfig.one_hand).
  - Bombs (`smoke`, `flash`; GT2): each fitted to its own model (`assets/models/grenades/`), held in a fist in the
    right hand alone, the lever under the palm, the fingers round its front and the thumb round its back; the left arm
    lowered and hidden. Its mark sits where GrenadeView draws the bomb in hand (HELD_AT), the bomb tipped as it tips it
    (HELD_TIP, mirrored in arms.py); in game the arms ride the bomb's square-to-view node and lift with it.
- **Solving.** `pose.py` places each hand on the replica's mesh (on a grip, the thumb's root and the index and little
  finger's knuckles at marks on it, rolled to the straightest wrist; on the rifle's handguard, a search for the cupped hand whose
  fingers wrap it), curls the fingers until they touch, the index onto the trigger, and bends each elbow to keep the
  wrist straight; last passes on the skinned mesh open any finger still touching and ease a pressing palm back (the
  thumb waiting for its hand), then seat each holding palm and close each holding finger until its glove all but
  touches. `arms.py` stops without writing if any face of the arms passes into a replica. Re-run
  it whenever a replica's model changes.
- **Shading.** In game the arms are drawn with pressed depth and take no shadows (ArmsView): the sun's shadow map on
  pressed depth broke into hard patches on the sleeve.
- **Not yet.** Pistols are one-handed until the two-handed, thumbs-forward hold of the owner's photos is solved. No
  arm clips for firing, reloading or the Sniper Rifle's bolt: the replica's own clips move its parts as before.
- **Budget.** `docs/CC0_ASSETS.md` › Size limits: first-person arms ≤ 40,000 triangles, ≤ 4 materials.
