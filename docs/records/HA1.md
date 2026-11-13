# HA1 · First-person arms and grips, made realistic

**Review:** REVIEW_LINE

Owner's ask (2026-11-12, with reference pictures from other games and photos of a hand): "go over the first person arms
and their grips on weapons to make them appear more realistic. When not aiming down sight with a rifle only the player's
left hand should be visible … When aiming down sight no hands should be visible. For pistols, the player should hold the
pistol with two hands … When aiming down sight on a pistol the hand should only be slightly visible. Go over all first
person view animations and make them higher quality. For the first person arms with no gloves I want you to improve the
quality and detail of the hand model and its textures." Then, on the first pictures: the right index finger "looks
unnatural", "the hands need detailed texture for the gloves and clothes. Make the models as detailed and high quality as
possible", and "the wrist to thumb joint also doesn't look natural". Two more looks at pictures followed (quoted under
Decisions). The ruling is in `docs/DECISIONS.md` › First-person hands.

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
- **A straight support arm, close along the rifle** (`GUARD` `upper` and `y`, `arms.straight_elbow`,
  `shoulder_behind`; the owner's third look: "the forearm/wrist for the rifle hold is bent in an unnatural way. The arm
  and wrist should be straight", and "try angle the left arm/hand on the rifle close to the replica"): the wrist bent
  50 degrees on the AEG and SMG and 34 on the Sniper, because the elbow hung from a fixed shoulder place far below
  the hand. The view never shows the shoulder, so the solve now starts from the hand: the forearm lies on the hand's
  own line and the shoulder goes the upper arm's length behind that elbow. The hand is turned 25 degrees off the
  bore (was 60) and sits 5 cm further forward on the AEG's handguard, so the forearm runs up beside the rifle 30
  degrees off the bore (was 40) with the wrist straight (0 to 1 degree) and its sleeve still passes the magazine;
  with the hand where it was, nothing under 45 degrees cleared the AEG's magazine. The hand stays pitched 15
  degrees, so the fingers stay hidden. The Compact SMG's handguard is 12 cm long with the magazine right behind
  it: 7 cm forward a fingertip showed past its front, 5 cm forward the sleeve needs 37 degrees to pass the
  magazine, so that is its hold (`SMG_GUARD` `search`), and its elbow hangs 10 degrees under the wrist's line
  (`sag`), without which the upper arm came into the view's foot.
- **The rifle hand back by the magazine** (`GUARD` `y`, `search`, `sag`, `tip_at`; `Hand.onto`; the owner's fifth
  look: "With no grip Move the left hand back and closer to the magazine on the rifles. If you need to move more of
  the forearm out of view that's ok"): the hand sits 4 cm further back on the AEG, its cuff at the magazine well's
  front, 28 mm on the Sniper (further back its magazine's housing holds the palm off the fore-end) and 7 mm on the
  Compact SMG, whose magazine was already right behind it. From there the
  sleeve needs 30 degrees of turn to pass the magazine (at 25 the forearm passes into it), so the forearm runs 38
  degrees off the bore, and the elbow hangs 12 degrees under the wrist's straight line, the bend a hand carrying a
  rifle's weight has, which takes the forearm lower in the view. Turned further across, fingers aimed level with
  their knuckles hooked up past the handguard's far side where the eye saw their tips, so each fingertip now aims
  3 cm ahead of its knuckle and `Hand.onto` keeps it under `tips_below`: only the thumb shows.
- **A fist round each foregrip** (`GRIP_LEFT` `upper`, `turn` and `press`, `VERTICAL_LEFT`, `ANGLED_LEFT`): the
  third look asked for the straight arm, which on a fist round an upright grip runs level along the bore, through
  the magazine, so the hand's marks are turned about the grip's middle (`pivot`): tilted, as a hand holds a hammer,
  so the forearm rises to it, and swung 35 degrees, so it comes from the left. The first cut (tilted 30, the index
  knuckle 18 mm under the rail and 5 mm off the grip's side) left the index finger no room: it lay open up the
  handguard's side, and the angled grip was held as a handguard, its arm 65 degrees off the bore. The owner's fourth
  look: "With a vertical or angled grip the hand is very bad. With a vertical grip the index finger should be under
  the replica and around the grip. Angled grip should be held similar to the vertical grip". Now both are a fist: the
  index knuckle about 30 mm under the rail and 12 mm off the grip's side (a finger's thickness, room to turn round
  its front), the index and middle fingers closed until they touch, the ring and little fingers at and under its foot,
  the thumb round its back. The vertical grip (64 mm since MQ2) is tilted 20 degrees (forearm rising 20, 24 off the
  bore); the angled grip's tall end is held the same way, tilted 12, because its raked front and rail plate leave
  the index less room. The wrist stays straight (under 1 degree) on both. His fifth look: "Move the hand up the
  vertical grip a bit more so more fingers grip it" (built: the fist 10 mm higher, tilted 8 degrees); his sixth: "The
  previous version was better, so go back to that but the hand should be further up the grip (with fingers wrapped
  around the grip and the thumb resting on the near side)" (built: the fourth look's fist 10 mm higher, the thumb
  forward along the grip's left side); his seventh, on those pictures: "That is still bad. Go back to the previous
  one". So the vertical grip's hold is the fourth look's exactly (`VERTICAL_LEFT`), and neither a higher fist nor a
  thumb on the near side stands; `test_ha1_grips.gd` keeps the thumb round each grip's back. That hold was fitted
  to MQ2's 64 mm grip, so the row MQ2 left in `docs/KNOWN_ISSUES.md` (holds posed on the 53 mm grip) is closed.
- **The thumb on the handguard** (`thumb_f`, `thumb_z`, `thumb_hug`; the owner's fourth look: "The thumb should be
  resting against the replica"): it reached 55 mm forward along the handguard's lower left edge, its tip past the
  handguard's front, so from the eye it stood beside the rifle. It lies 35 mm forward and 5 mm higher, up on the side
  face, held close along its length.
- **The wrist's size** (`glove.WRIST_FULL`, `wrist_full`; the owner: "too thin at the wrist", then of the fix:
  "Wrists are slightly too thick holding rifles"): the wrist measured 50 by 39 mm against a hand 85 wide; widened a
  fifth and thickened an eighth with the sleeve's cuff 10.5 mm off the arm (was 8) it read too thick, so half of that
  stands: a tenth wider, 6.5% thicker, the cuff 9.2 mm off.
- **Bots hold a bare rifle where the arms do** (`FigureView.support_mark`): the figures' left hand was held no
  further forward than the grip's mount, which the arms' hold was always behind. The straight arm's hand sits ahead
  of it on the AEG, and the bots' hand was drawn 5.5 cm back off the arms' finger marks. With no grip fitted there is
  now no limit (the arms' hold is built against the replica); behind a fitted grip it moves back as before.
- **A reload keeps the arm's show to the hold's** (`magazine.KEEP_*`, `MagChange.arm_shown`): leaving the hold the
  elbow kept the hold's own place while the hand dropped, which swung a straight forearm up into view. The elbow now
  goes toward the solved one until no more of the arm shows than the hold showed, and where the replica's cant still
  lifts the arm past that the hand draws further down off the hold (9 cm on the AEG, 6 was the rule:
  `CLEAR_MORE`). A foregrip's fist shows less arm than the replica's own hold, and the magazine is carried the same
  way from either, so `test_bp8_arms`'s limit for a foregrip's reload is the replica's own hold's; the aimed elbow
  test's limit is 2 cm in (was 3), the straight arm's elbow already lying close to the rifle at the hip.
- **Pistols in both hands** (`<id>_two_Hold`, `<id>_two_Reload`; `ArmsView.TWO_HANDS`, `clip_base`): the left hand wraps
  the right hand's fingers (`SUPPORT_LEFT`), solved against the pistol and the right arm as posed. The owner's second
  look: "The pistol grip shows the players left hand fingers ... They should be resting on top of the right hand and out
  of sight. The right hand thumb should be resting on the left hand. The player is gripping the pistol tight." The first
  solve laid the left hand by its marks and counted how far it was pushed off them; the right thumb, lying where the
  left hand's heel belongs, pushed it out flat beside the grip, and its fingers closed short of the right hand in a
  fist. Now (`support_pose`, `lay_right_thumb`) the left hand is placed without the right thumb's outer sections, turned
  to where its palm lies closest over the pistol and the right fingers; its fingers start open and close round the right
  hand's (`curl_more`); then the right thumb is laid again on the left hand. The left shoulder sits 7 cm further in, so
  its forearm comes up beside the right one and the wrist bends less. The owner's third look, of the view over the
  sights: "the player can see a gap between the left hand and the pistol grip. The hand should be pressed against the
  handle/grip". Measured, the upper palm and the left thumb stood 8 to 20 mm off the grip's bare left side, the thumb in
  an arch over it. The turn is now scored by how close the hand's skin lies on that side (`bare`, `bare_cost`), within
  the rolls that leave the thumb a clear place flat on the frame: the palm and thumb lie 0 to 5 mm off it and the right
  thumb keeps the place he approved. Through a reload the left hand draws off to the left, changes the magazine and
  comes back; its elbow keeps 9 cm off the right arm's bones (`magazine.ARM_CLEAR`); the right thumb keeps its raised
  place while the left hand is away. Default taken: **the bots stay one-handed** (HG1; they copy `<id>_Hold`, which is
  unchanged), and **the pistols keep their hip place** of 2026-11-06 (nearer places cut the hands off at the screen's
  foot).
- **The Cyber Pistol takes the GBB's hold** (`CYBER_RIGHT`, `CYBER_SUPPORT`, `CYBER_LIFT`; the owner: "Cyber pistol
  should have same grip as gbb pistol ... the thumb looks too long (it should stick out like the thumb in the gbb
  shot)"): its grip was reshaped to the GBB's sections (MQ1B, #324), so the GBB's marks seat the same hands on it, 7 mm
  higher because its trigger hangs that much higher; the thumb pinned flat across the old slab is gone. The merged
  grip keeps flat sides to square back corners and a frame at full width ahead of the grip, where the GBB's round
  off and narrow: on the GBB's exact marks the left thumb's root lay in the corner, the thumb found no clear place
  along the frame and stood out sideways, and the right thumb was laid flat across after it (the very look he turned
  down). So the support hand sits 3 mm further out and back (`CYBER_OUT`) at the GBB's turn (15 and 4 degrees,
  pinned), and the right thumb's turn in the one-handed hold is searched, not the GBB's (there it closed into the
  frame and was eased 20 degrees out into the air). The trigger finger's second search is kept only when it ends no
  further from the trigger (`trigger_again`). The bots' one-handed Cyber hold changes with it.
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
  reaches for the magazine. The Pump Shotgun (SH2, merged while this was open) takes the rifles' amounts, its hand
  off the pump and out of view by the time the sight is up (SH2 left this to HA1: "aimed, the left fingertips show
  beside the receiver"); its hold is built by this task's guard method (wrist 11 degrees, nothing passing), and
  `test_sh2_qa.gd` now expects the other long replicas' hold marks where their holds are solved, not at the hip.
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

- With no grip the rifles' left index and middle fingers lie open along the handguard's far side, under its top,
  rather than wrapped up it, and reach past the SMG's narrow front (a bot close up shows it, your view never); aimed, the Cyber's right thumb lies a little flatter than the GBB's; on the Angled Grip's short
  tall end the ring and little fingers close under its foot (`docs/KNOWN_ISSUES.md` › Graphics).
- The skin's atlas has about 530 texels (of 1.46 million) claimed by two places on the hand, at the thumb's web; no
  seam shows in the pictures.
