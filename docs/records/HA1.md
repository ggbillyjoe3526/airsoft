# HA1 · First-person arms and grips, made realistic

**Review:** REVIEW_LINE

Owner's ask (2026-11-12, with reference pictures from other games and photos of a hand): "go over the first person
arms and their grips on weapons to make them appear more realistic. When not aiming down sight with a rifle only the
player's left hand should be visible … When aiming down sight no hands should be visible. For pistols, the player
should hold the pistol with two hands … When aiming down sight on a pistol the hand should only be slightly visible.
Go over all first person view animations and make them higher quality. For the first person arms with no gloves I
want you to improve the quality and detail of the hand model and its textures." Then, on the first pictures: the right
index finger "looks unnatural", "the hands need detailed texture for the gloves and clothes. Make the models as
detailed and high quality as possible", and "the wrist to thumb joint also doesn't look natural". The ruling is in
`docs/DECISIONS.md` › First-person hands.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
ATTEMPT_ROWS

## Decisions

- **The references are other games'.** They set where the hands sit and how much of them shows; nothing of their art
  is copied. Skin, glove and sleeve are our own designs, painted by our own scripts.
- **Rifles at the hip** (`ViewModelConfig.hip`: AEG and Sniper at 0.10, -0.135, -0.19, the Compact SMG at 0.10,
  -0.165, -0.24; all were 0.12, -0.19, -0.26): nearer and lower, so the rifle is larger, the left hand on the handguard
  shows and the right hand lies under the screen's foot. The owner's second look: the SMG was "too high. It should be
  a similar angle and scale to the rifles"; it is a shorter replica, so the same place drew it larger and higher, and
  its own place draws it at the AEG's size. The holds are still solved at their old place (`arms.py` RIFLE_HIP): the
  arms ride the replica, so moving the replica moves them as one. `magazine.View` reads the game's hip, so the
  reload's "down out of view" is measured from where the game draws it, and the build's pictures are taken from there
  (`GAME_HIP`).
- **Only the left thumb shows on a rifle** (`GUARD`, `SNIPER_GUARD`, `SMG_GUARD`; the owner: "You can still see the
  players fingers on the right side of the AEG. They should not be visible: only the thumb of the left hand"): the
  hand cups the handguard from below, pitched 15 degrees (was 40), its fingertips on the far side 14 to 18 mm lower,
  under the rail's edge. **This re-solves the holds the owner approved in BL4, BP8 and BW2**, on his word here, and
  the bots copy the new ones.
- **A fuller wrist** (`glove.WRIST_FULL`, `wrist_full`; the owner: "too thin at the wrist"): the wrist measured 50 by
  39 mm against a hand 85 wide; it is widened a fifth and thickened an eighth between the cuff and the heel of the
  hand, and the sleeve stands 10.5 mm off the arm at its cuff (was 8).
- **Pistols in both hands** (`<id>_two_Hold`, `<id>_two_Reload`; `ArmsView.TWO_HANDS`, `clip_base`): the left hand
  wraps the right hand's fingers (`SUPPORT_LEFT`, `CYBER_SUPPORT`), solved against the pistol and the right arm as
  posed. The owner's second look: "The pistol grip shows the players left hand fingers ... They should be resting on
  top of the right hand and out of sight. The right hand thumb should be resting on the left hand. The player is
  gripping the pistol tight." The first solve laid the left hand by its marks and counted how far it was pushed off
  them; the right thumb, lying where the left hand's heel belongs, pushed it out flat beside the grip, and its fingers
  closed short of the right hand in a fist. Now (`support_pose`, `lay_right_thumb`) the left hand is placed without
  the right thumb's outer sections, turned to where its palm lies closest over the pistol and the right fingers; its
  fingers start open and close round the right hand's (`curl_more`); then the right thumb is laid again on the left
  hand. The left shoulder sits 7 cm further in, so its forearm comes up beside the right one and the wrist bends
  less. Through a reload the left hand draws off to the left, changes the magazine and comes back; its elbow keeps
  9 cm off the right arm's bones (`magazine.ARM_CLEAR`); the right thumb keeps its raised place while the left hand is
  away. Default taken: **the bots stay one-handed** (HG1; they copy `<id>_Hold`, which is unchanged), and **the
  pistols keep their hip place** of 2026-11-06 (nearer places cut the hands off at the screen's foot).
- **Aimed, a rifle's hands are out of view, never faded** (`ArmsTuck`, `ViewModelConfig.aim_tuck`; the owner: "the
  hands should not fade out of view. When the animation plays to ADS (except for pistols) the hands are simply out of
  view. At most a small tip of the players left hand thumb can be visible"): the first pass faded them, which he
  turned down. As the sight comes up the left shoulder is carried in and down by `aim_tuck` times the raise and the
  elbow found again under the line from shoulder to wrist, so the forearm and sleeve leave the screen behind the
  replica, its bones written after the clip each frame the raise changes. The hand on the handguard still showed
  past the replica's sides (the Sniper's and SMG's narrow fore-ends, and the AEG's with any optic, which sits the eye
  higher), so it slides back and down along the replica behind the receiver (`aim_slide`, 22 cm back): it holds the
  handguard until the sight is 0.4 of the way up, when the replica is coming in front of it, and has slid by 0.9
  (`aim_slide_span`). Checked on pictures with iron sights, each optic and each grip. The right hand is under the
  screen's foot already. A reload lowers the sight (`Aiming.can_aim`), so the hand is the clip's again before it
  reaches for the magazine.
- **Aimed, a pistol keeps the tops of the hands** (`aim_hands_hint`, `aim_hint_span` 0.3 to 0.8 of the raise,
  `aim_hint_below` 80 to 120 mm under the sight line; `ArmsFade`, `arms_fade.gdshader`): what lies below fades, so
  only the top of the hands shows under the slide (the owner picked this from pictures, over whole solid hands and
  over a fainter edge; at 45 to 75 mm the hands were see-through all over, which read as a fault). The arms wear
  fading copies of their materials only while the sight is raised at all. The depth is drawn first where the arm is
  whole, so a fading hand never shows its far side through its near one.
- **The right index finger** (`PISTOL_RIGHT`): `index_left` was the far a fingertip may pass the trigger's middle, and
  at 5 mm it held the finger straight across the guard; at 22 mm, with an arch target on the middle joint
  (`index_arc`), the finger curls through the guard and its pad sits on the trigger (4.5 mm off its mark).
- **Wrist to thumb** (`Heel_<side>`, `glove.heel_weights`, `pose.Rig.fk`): the skin between them wrung because one
  bone took all of the thumb's twist. A helper bone takes the thumb's swing and half its twist, and the first bone's
  weights are shared along it. ArmsThrow turns it with the thumb.
- **Painted maps, 2K each** (`skin.py`, `glove_paint.py`, `sleeve_paint.py`): the old glove read as a mitten because a
  flat tiled weave covered good geometry. Each texel is now painted from where it lies on the hand: skin (tones,
  knuckle folds, creases, veins, pores, hair, nails), glove (knit back, leather palm, fourchettes, seams and stitches,
  thumb saddle, flex ribs, caps, wear) with its kit in the atlas's clear square (moulded rubber shell with a boss a
  knuckle, stitched patch, ribbed cuff, webbing strap), and sleeve (ripstop, folds, felled seam, cuff band). One atlas
  layout serves skin and glove, so the hand's surface is one mesh (`HandSurface_<side>`) that wears either: 38,900
  triangles drawn gloved, 34,500 skin only, four materials, a 5.9 MB file (WebP inside). Imported VRAM compressed as
  the project's other models (about 42 MB of texture memory: BC7 colour, RGTC normals, DXT1 roughness).
- **The AEG's reload lifts 8 cm, was 10** (`reload_move_by`): at the nearer hip the left forearm showed 8 cm past the
  wrist mid reload, over BP8's 7 cm.
- **The skin's tones run deep** (`skin.TONE`, `MOTTLE_SHADE` and its neighbours): a map that looked right in Blender
  read pale and smooth in the game, whose light and muted colours flatten it; the creases shade about twice as far.
- **A fading copy reads the metal map** (`ArmsFade`, `metallic_map`): a glTF material's metal is 1 times its map's
  blue, so a copy with the number alone would have drawn the arms as metal through the fade.
- **Skin-only arms** now show that painted skin (the nails' material on the hand's surface);
  `ViewModelConfig.skin_arms` and its tint are gone. A robot's arms are plain colours with the painted maps taken off.
- **Life in the hands** (`HandsMotion`, `HandsLifeConfig`; the amounts are first values for the owner's play): a bob
  with the ground covered (2.7 m a cycle, 3.4 mm to each side), breathing at rest (3.8 s, 1.4 mm), a lean into a
  strafe (1.8°), a trail through a jump and a dip on landing, a push through a crouch, a sprung flick (about 0.7°) and
  roll with each shot, a draw that settles, a cant as the sight comes up, and a roll behind a turn (`sway_roll`).
  Drawn by moving ReplicaView's own node about the replica's place, so the pose under it (the hip, the sight line
  through the eye) is untouched and every older test of it holds; aimed, 15% is left; Reduced motion takes its sway
  and kick shares. The bomb in hand takes the same life (GrenadeView). The sprint carry eases in and out.
- **Not done, offered:** a narrower field of view for the view model alone (the references' rifles fill more of the
  screen because of one) would touch every view-model material and the optic glass; it is the owner's call.

## Known issues left

- The skin's atlas has about 530 texels (of 1.46 million) claimed by two places on the hand, at the thumb's web; no
  seam shows in the pictures.
