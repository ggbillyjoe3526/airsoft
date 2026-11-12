# First-person arms

`arms.glb` (glTF binary): your own arms in the first-person view, in dark olive gloves and sleeves, holding the replica in
hand (BL4, 2026-11-05). Built by `tools/blender/arms/arms.py` (`python3 -I tools/blender/arms/arms.py .`, pip
`bpy==5.2.3`); drawn by `game/play/arms_view.gd` (ArmsView, under ReplicaView).

- **Space.** Metres, Blender +Y forward from the eye (at the origin), +Z up; exported +Y up, as every model here, so
  in Godot the eye looks along -z.
- **Skeleton.** `Arms`: each side's `Shoulder`, `UpperArm`, `Forearm`, `Hand`, `Thumb1-3`, `Index1-3`, `Middle1-3`,
  `Ring1-3`, `Pinky1-3` and `Grip` with `_R` or `_L`, the figures' bone names, and `Heel_R`/`Heel_L` (HA1): a
  helper on the thumb's first bone that takes its swing and half its twist, so the skin between the wrist and the
  thumb doesn't wring (`glove.heel_weights`, `pose.Rig.fk`; ArmsThrow turns it with the thumb).
- **Mesh.** Four objects a side (HA1; 38,900 triangles drawn gloved, 34,500 skin only): `Arm_<side>` the sleeve,
  `HandSurface_<side>` the hand's surface (the glove's cloth; skin only, the game puts the skin's material on it),
  `GloveKit_<side>` the glove's kit (shell, pads, patch, cuff, strap, tab) and `Nails_<side>` the fingernails (skin
  only). The MakeHuman base mesh's arm and hand (CC0,
  `tools/blender/arms/source/`) under a glove (skin + 1.1 mm, `glove.py`, raised over the hand's forms: the web
  muscle, the thumb's and index finger's bones, the finger joints, with a crease across each) with one moulded knuckle
  shell over the four knuckles (domed, with a padded rim), a round pad on each finger's first section, a suede palm
  patch, a
  cuff and wrist strap, and a sleeve rolled over the cuff with a banded hem, ending 13 cm above the elbow (the view
  never shows the shoulder).
- **Materials.** Four, each painted at 2K (colour, normal, roughness; WebP in the file) from where every texel lies
  on the hand or arm (HA1, the owner: detailed texture for the hands, gloves and clothes). Original designs, no
  maker's; the owner's reference pictures set placement and the level of detail only.
  - `Skin` (`skin.py`, maps `ArmsSkin*`): the bare hand unwrapped into an atlas of its own (about 0.19 mm a texel):
    back and palm tones, knuckle folds, the palm's creases, fine lines, veins, pores and hair; the nails in a tile
    of the same atlas.
  - `Glove` and `GloveArmour` (`glove_paint.py`, maps `ArmsGlove*`, one set for both): over the skin's atlas, a
    knit back, a leather palm, fourchettes, seams with top stitching, a thumb saddle, flex ribs, fingertip caps and
    wear; the kit in the atlas's clear square: moulded rubber (a boss over each knuckle, grooves between), the
    stitched palm patch, the ribbed cuff, the webbing strap.
  - `Sleeve` (`sleeve_paint.py`, maps `ArmsSleeve*`): unrolled round the forearm: ripstop, folds deepest at the
    elbow and behind the cuff, a felled seam with two stitch rows, the cuff's band, wear.
  A robot's arms are plain colours in game (ViewModelConfig.robot_arms).
- **Pictures.** `BL_PREVIEW=<folder>` draws each hold as it is solved (`preview.py`; `BL_PREVIEW_VIEWS`,
  `BL_PREVIEW_NEAR`, and `BL_PREVIEW_HIDE=Arm_,HandSurface_,GloveKit_ BL_PREVIEW_SHOW=Skin_,Nails_` for bare hands);
  `BL_ONLY=<id>` solves one replica (`none`: the mesh and maps alone), `BL_SKIN_OUT=<folder>` saves the maps,
  `BL_HIP` and `BL_PISTOL_HIP` try another hip place. Never ship a partial build: run it whole.
- **Holds.** One per replica and bomb: a clip `<id>_Hold` (`aeg`, `pistol`, `cyber`, `sniper`, `smoke`, `flash`)
  posing both arms, and an empty `Hold_<id>` where that replica's origin sits in it (at ViewModelConfig.hip). In game
  the arms ride the replica's node with that empty on its origin, so they follow its sway, kick, cant and drop.
  - The AEG Rifle: the right hand high on the pistol grip, the little finger round its foot, index on the trigger,
    thumb wrapped round the grip's left side; the left hand under the handguard's middle, its forearm rising to it from below, fingers closed under
    its right side out of the eye's sight (HA1, the owner: "only the thumb of the left hand"), thumb along its left side.
  - Pistols (`pistol`, `cyber`): held high in the right hand, the web of the hand on the back strap under the
    beavertail, the fingers closed up under the trigger guard with the little finger on the grip, the thumb forward
    along the frame's left side under the slide. `<id>_Hold` lowers the left arm (the bots' one-handed hold);
    `<id>_two_Hold` and `<id>_two_Reload` (HA1, yours: ArmsView.TWO_HANDS) bring the left hand up to wrap the right
    hand's fingers tight, its heel on the grip's bare left side, and lay the right thumb on it (the owner: "the right
    hand thumb should be resting on the left hand").
  - Bombs (`smoke`, `flash`; GT2): each fitted to its own model (`assets/models/grenades/`), held in a fist in the
    right hand alone, the lever under the palm, the fingers round its front and the thumb round its back; the left arm
    lowered and hidden. Its mark sits where GrenadeView draws the bomb in hand (HELD_AT), the bomb tipped as it tips it
    (HELD_TIP, mirrored in arms.py); in game the arms ride the bomb's square-to-view node, and throw it posed by IK
    over the hold (ArmsThrow, GT3: the left arm shown while it pulls the pin).
- **Solving.** `pose.py` places each hand on the replica's mesh (on a grip, the thumb's root and the index and little
  finger's knuckles at marks on it, rolled to the straightest wrist; on the rifle's handguard, a search for the cupped hand whose
  fingers wrap it), curls the fingers until they touch, the index onto the trigger, and bends each elbow to keep the
  wrist straight; last passes on the skinned mesh open any finger still touching and ease a pressing palm back (the
  thumb waiting for its hand), then seat each holding palm and close each holding finger until its glove all but
  touches. `arms.py` stops without writing if any face of the arms passes into a replica. Re-run
  it whenever a replica's model changes.
- **The bots' hands take the same holds** (HG1, FigureArmsHold): a change to a hold here changes how every bot
  holds that replica too.
- **Shading.** In game the arms are drawn with pressed depth and take no shadows (ArmsView): the sun's shadow map on
  pressed depth broke into hard patches on the sleeve.
- **Budget.** `docs/CC0_ASSETS.md` › Size limits: first-person arms ≤ 8 MB, ≤ 40,000 triangles (as drawn in either
  look), ≤ 4 materials, 2K textures.
