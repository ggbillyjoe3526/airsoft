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
| 2026-11-13 | 1 | build thread | ✓ 6,533 of 6,535 (2 pending, as on main) | 6/8 Retry | checks 1 and 7: the hand unmeasured against the owner's photo, the bare hand's shape and paint short of it; the record's claims ahead of the pictures |
| 2026-11-13 | 2 | build thread | ✓ 6,617 of 6,619 (2 pending, as on main) | 7/8 Retry | check 1: fingertips seen at the AEG's hip; far-side fingers floating under the handguard; a seam on the palm and a step at the nails; the Sniper's right hand off its trigger; the thumb unmeasured |
| 2026-11-13 | 3 | build thread | ✓ 6,619 of 6,621 (2 pending, as on main) | 7/8 Retry | check 1: a far-side finger on the AEG past the handguard's front end; the Sniper's and the SMG's far-side fingers pinched into one another |
| 2026-11-13 | 4 | build thread | ✓ 6,647 of 6,649 (2 pending, as on main) | 7/8 Retry | check 1: the SMG's rearmost far-side finger curled in a loop and the Sniper's leaning back from its neighbour (a closing pass ran after the row was laid) |
ATTEMPT5_ROW

## Decisions

- **The references are other games'.** They set where the hands sit and how much of them shows; nothing of their art
  is copied. Skin, glove and sleeve are our own designs, painted by our own scripts.
- **Rifles at the hip** (`ViewModelConfig.hip`: AEG and Sniper at 0.10, -0.135, -0.19, the Compact SMG at 0.10,
  -0.165, -0.24; all were 0.12, -0.19, -0.26): nearer and lower, so the rifle is larger, the left hand on the handguard
  shows and the right hand lies under the screen's foot. The owner's second look: the SMG was "too high. It should be
  a similar angle and scale to the rifles"; it is a shorter replica, so the same place drew it larger and higher, and
  its own place draws it at the AEG's size. The holds are still solved at their old place (`hold_tables.py`
  RIFLE_HIP): the arms ride the replica, so moving the replica moves them as one. `magazine.View` reads the game's hip, so the
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
  unchanged). The pistols kept their hip place of 2026-11-06 until the owner's pick on attempt 2 (below: 25 cm from
  the eye on the same line, which keeps the hands off the screen's foot as a nearer place alone did not).
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
  further from the trigger (`trigger_again`). The bots' one-handed Cyber hold changes with it. This closes MQ1B's
  row in `docs/KNOWN_ISSUES.md` (the hold "posed on the old slab grip ... until the first-person arms task refits
  it").
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
  QA's third run found the drawing in left its places in the forearm and hand bones, which no clip keys, so each
  aimed frame read the last one's back: after 10 s aimed the fingertips sat 2 to 8 cm off the hold at the hip.
  `ArmsTuck.clear` now rests all three bones' places and sizes before the clip poses them
  (`test_ha1_shotgun.gd` holds the sight up for seconds on every rifle).
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
  layout serves skin and glove (the bare hand, `Skin_<side>`, and the glove's cloth over it, `HandSurface_<side>`,
  are the same faces): 38,900 triangles drawn gloved, 34,500 skin only, four materials, a 6.5 MB file (WebP
  inside). Imported VRAM compressed as the project's other models (about 42 MB of texture memory: BC7 colour, RGTC
  normals, DXT1 roughness).
- **The AEG's reload lifts 8 cm, was 10** (`reload_move_by`): at the nearer hip the left forearm showed 8 cm past the
  wrist mid reload, over BP8's 7 cm.
- **The skin's tones run deep** (`skin.TONE`, `MOTTLE_SHADE` and its neighbours): a map that looked right in Blender
  read pale and smooth in the game, whose light and muted colours flatten it; the creases shade about twice as far.
- **A fading copy reads the metal map** (`ArmsFade`, `metallic_map`): a glTF material's metal is 1 times its map's
  blue, so a copy with the number alone would have drawn the arms as metal through the fade.
- **Skin-only arms** now show that painted skin; `ViewModelConfig.skin_arms` and its tint are gone. A robot's arms
  are plain colours with the painted maps taken off.
- **The far-side fingers lie open under the handguard** (attempt 2; `GUARD` `tip_back` and `tip_most`, `Hand.onto`'s
  `back`): the critic, from the far side, saw the ring and little fingers knotted (knuckle straight, middle joint
  shut to 100 degrees). A resting finger's knuckle may now bend back up to 15 degrees and its middle joint closes no
  further than 45 (25 under the Sniper's narrow fore-end, where 45 still looped the little finger), so every joint
  stays well under a right angle (`test_no_finger_under_a_bare_handguard_is_knotted`) with the tips still under
  `tips_below`. The Pump Shotgun's hold keeps SH2's figures.
- **The far-side fingers hook onto the handguard, hidden from the eye** (attempt 3; `GUARD` `tip_at`, `tip_cup`,
  `tips_behind`, `tip_reach`, `Hand.seen`, `hold_tables.game_eyes`): the critic's second look found the open fingers
  floating beside the handguard from the far side, and a fingertip showing past the AEG's handguard from the eye at
  the hip. The four fingers now hook up onto the right side together, pads on its lower half, each turned a little
  about its own line as a cupped hand's are, the little finger's mark a little further forward on the Sniper
  and the SMG (`pinky_ahead`: aimed as the others it folded into a hook); and the solve counts against a pose
  the share of each finger that the game's eye (the hip place, 15 mm above it and 20 mm to its right) sees past the
  replica. `test_no_left_finger_shows_past_the_replica_from_the_eye_at_the_hip` casts rays in Godot from the view's
  origin at the skinned gloved and bare meshes' far-side finger vertices (it fails on attempt 2's model: 110 of the
  AEG's 1,273 points showed). The palm, the thumb and the arm are where the owner approved them (a tilted palm
  wrapped better but moved the thumb in his view, so it was dropped). The Pump Shotgun keeps SH2's marks and
  settings; under the same check its index, middle and ring fingers close a few degrees further, and the test covers
  it too. The foregrips' fists are untouched (the same bends in the build's log).
- **The far-side fingers stand side by side behind the front end; the AEG's cannot** (attempt 4; `front_hard`,
  `tip_apart`, `sight.crowd`, `FRONT_CLEAR`, `FINGER_APART`): the critic's third look found a fingertip on the AEG
  past the handguard's front end, and neighbouring fingers pinched into one another on the Sniper and the SMG. On
  those two every fingertip now keeps 5 mm behind the front end as firmly as it keeps out of the replica, and each
  finger is laid a finger's width (16 mm between middle lines) from the one laid before it, so no two pass into one
  another (were 3 to 10 mm apart). What attempt 4's pictures showed is not what that aimed for: the index, middle and
  ring fingers stood side by side, but the little finger was curled back, on the SMG into a closed loop, on the Sniper
  leaning away from the ring finger with a V of daylight between them (the critic's fourth look; fixed in attempt 5,
  the next entry). `test_every_left_finger_keeps_behind_the_handguard_s_front_end` holds the front end on the skinned
  gloved and bare meshes. **The AEG keeps attempt 3's fingers**: its handguard ends 32 mm
  ahead of the index finger's knuckle with the hand where the owner approved it (the magazine well stops the hand
  going further back; his straight wrist keeps the fingers 47 degrees off the bore, so each finger's first bone
  already runs 23 to 29 mm forward before it can turn up the side), and the eye sees anything on that side above
  about z 0.055. Sixteen trial solves (a row of fingertips, natural curls, a wider swing, a firm front limit, fingers
  kept apart) each ended with a finger passing through its neighbour, 10 to 12 % of the middle finger showing from
  the eye, or fingers curled back in loops beside the handguard. So on the AEG the middle fingertip rests 13 mm past
  the handguard's end beside the front sight's base, hidden from the eye, and the test holds it to 15 mm. The palm
  cannot be raised or turned to help: either moves the thumb the owner approved. Asked of the owner on a card
  (2026-11-13 21:10): keep the hand as approved, or turn it across with the wrist bent. **He chose the card's "Keep it
  as approved"** (21:21), which read: "Nothing in your view changes. On a bot's AEG one fingertip rests about 1 cm
  past the handguard's end, and I finish with that written down as accepted."
- **A finger laid in the row is not closed again** (attempt 5; `hold_solve.py`, `sight.crowd`, `TIP_SLACK`): the
  critic's fourth look found the SMG's rearmost far-side finger in a closed loop and the Sniper's leaning back from
  its neighbour (it named the index finger; in the pictures and the build's log it is the little finger, the one
  nearest the magazine). The cause was not the row: after the fingers were laid, the solve's closing passes
  (`tighten`, `wrap`) curled the little finger further until its glove touched something, 51 degrees on the SMG and
  10 on the Sniper, which took its tip back behind its own knuckle. Those passes now skip the four fingers of a hand
  laid in a row (the thumb still closes; the AEG and the Pump Shotgun lay no row, so their fingers are as before).
  The row itself also holds each tip within a finger's width and 4 mm of the tip laid before it and no further back
  along the handguard than its own knuckle, and the Sniper's marks lead their knuckles by 4 cm, not 5, which its
  little finger reaches. On the SMG those passes had also been what brought the index finger's glove behind the
  front end, by a hundredth of a millimetre: swung at most 25 degrees sideways at its knuckle, the row's search had
  no place for it there, so attempt 4's "as firmly as it keeps out of the replica" was not yet true of that finger.
  It may now swing 30 degrees (`tip_swing`), which lays it 2 mm behind the limit with the other three beside it. In
  the pictures the four fingers now stand side by side up the side face on both, tips
  pointing up toward the bore; on the SMG a small opening still shows under the little finger's arch, since the
  handguard is narrower there than the finger is long. Measured on the built model: neighbouring fingertips
  TIPS_SMG mm apart on the SMG and TIPS_SN mm on the Sniper (round 4: up to 36 mm), every tip ahead of its knuckle.
  `test_each_fingertip_lies_ahead_of_its_knuckle_and_beside_its_neighbour_s` (test_ha1_qa3.gd) holds both on the
  skinned mesh, and fails on attempt 4's model (the little finger's tip behind its knuckle on both; ring to little
  fingertip 35.0 mm on the Sniper, 36.4 mm on the SMG).
- **The Sniper's right hand holds the stock's wrist** (attempt 3; `SNIPER_RIGHT` `index_soft`, `swing_search`,
  `press`): the trigger finger lay straight under the guard, 2 cm short. Its coarse search missed the pocket inside
  the guard (a gloved fingertip has 1 to 2 mm to spare there), so that search now forgives touching and the fine
  steps walk to a clear pose: the pad rests 0.7 mm off the trigger. The middle finger, which no curl cleared at the
  AEG's swing, is tried swung further (8 degrees found) and closes round the wrist under the guard with the ring and
  little fingers.
- **Palm and nails** (attempt 3; `skin.PAD_EDGE`, `glove.NAIL_ROOT`): the palm's pads fade out toward the fingers'
  roots, was a hard arc at the index finger's base, and each nail thins to its root so it grows out of the skin. No
  colour changed (the owner: "Keep the texture as is").
- **The thumb against the photo** (attempt 3; `preview.REST_THUMB`, `hand_ratios.py … thumb`): `BL_REST` also draws
  the hand with its thumb held out as the photo's, and the thumb from its web to its tip over the middle finger
  measures 0.689 against the photo's 0.710 (-2.9 %).
- **The bare hand against the owner's photo** (attempt 2; `hand_ratios.py`, `BL_REST`, `preview.rest_hand`): the
  critic asked for the hand flat from its back beside `hand-skin-photo.jpg` and five ratios within 10 %. Measured
  (model against photo, before): hand length to palm width -8.9 %, middle finger to palm length +2.2 %, index to ring
  finger -3.4 %, little to middle finger -15.7 %, wrist to palm width -13.7 %, the middle finger's width to its
  length +2.5 %, the index finger's width to the palm's -10.9 %. So the little finger is 12 % longer from its knuckle
  (`PINKY_LONGER`), every finger 0.35 mm fuller (`FINGER_FULL`), the hand 3.5 % narrower across the knuckles
  (`HAND_NARROW`), and the bare wrist 8 % wider and 5 % thicker than the gloved one (`SKIN_WRIST_FULL`; the gloved
  wrist is the owner's fourth look and stays). After: -6.7, +2.1, -2.6, -5.0, -5.2, +2.5 and -7.7 %. The thumb's
  reach was not measured: the photo's thumb is held out and the model's rests in, so its tip's distance says nothing
  of its length.
- **The bare hand is a mesh of its own** (attempt 2; `Skin_<side>`, `ArmsView.SKIN_PREFIX`): skin only, the game drew
  the glove's cloth in the skin's material, so the bare hand had the glove's shape, its wrist and its even, fuller
  thumb (the critic: "thick, even tubes"), and a nail laid on a slimmer thumb would have sunk into it. The model now
  keeps the bare hand it paints from: the same faces with the fuller wrist and a thumb waisted 7 % along its first
  bone and tapered 16 % to its tip (`glove.thumb_taper`), the nails on that, the thumb's nail larger. The game shows
  it and its nails skin only and the glove's cloth and kit gloved; no material is swapped. The file holds 67,400
  triangles; either look still draws what it did.
- **The skin's forms are in the colour too** (attempt 2; `skin.FORM_SHADE`, `FLUSH_SHADE`, `CREASE_SHADE`,
  `TENDON_FORM`): the critic found the bare skin "one flat tone" in game. The game's even light and no shadow on the
  arms leave a normal map little to do, so each knuckle, tendon and vein is drawn a little lighter on its crown and
  darker round its foot, the knuckles' flush and the creases' shade run deeper, the heights are about two thirds
  greater, and the thumb has its own tendon along its back (faded out before the atlas's cut between back and palm:
  run over it, the ridge drew a hard line). Judged in game at 2560 by 1440 (`render_fp.gd` `size:`): at 1280 by 720
  a wrinkle is under a pixel.
- **No white on the nails, subtler tendons** (the owner, 2026-11-13 14:01, on the first in-game pictures of that
  skin: "Remove the white finger nail tips, make the tendons more subtle"; then "Keep the texture as is"): the
  nail's white free edge is gone (nails cut short), its moon is a faint paler patch (`skin.MOON` 0.30, was a white
  0.75), and a tendon takes 0.22 of a knuckle's shade (was a half) on a ridge of 0.4 mm (was 0.7). The knuckles,
  veins, creases and the skin's grain stay as he saw them. Of the picture of it: "Perfect" (14:17).
- **The atlas is packed by trial** (attempt 2; `skin.pack`, `PACKS`): the longer little finger made Blender's packer
  lay the same islands out so that the glove's kit lost a third of its square (0.40 mm a texel, from 0.26). The
  hand's islands are now packed into 100, 88, 80 and 72 % of the atlas's width and the layout kept is the one that
  gives the hand and the kit the most texels between them: the hand 0.20 mm a texel (was 0.19), the kit 0.24.
- **The Sniper's bolt pull swings the elbow clear** (attempt 2; `cycle.Work.clear_arm`, `ARM_OUT`): with the
  re-proportioned hand the knob's grip moved a fraction and the right sleeve passed into the stock at six keys, bolt
  drawn back. Where a key's sleeve passes into the replica the elbow swings out a centimetre at a time until it
  clears.
- **The pistols sit 25 cm from the eye** (`ViewModelConfig.hip`, `reload_move_by`; the owner's pick, 2026-11-13
  08:38, `docs/DECISIONS.md` › First-person hands): the critic found them small beside the references; on a picture
  of 34, 29 and 25 cm he chose 25. The place is on the same line from the eye as his of 2026-11-06, so they draw a
  third larger where they were; their reload's lift and move inwards are drawn in by the same share (0.074 and
  0.044 m, were 0.1 and 0.06), so a reload crosses the same part of the screen. The holds stay as solved
  (`hold_tables.py` PISTOL_HIP): the arms ride the replica, as the rifles' do.
- **The Pump Shotgun's trigger finger arches as it did** (attempt 2; `SHOTGUN_RIGHT` `index_arc`, `pose.ARC_TIP`):
  on the re-proportioned hand the search reached the blade with a straighter finger (its bends 87 degrees together,
  112 before; SH2's test asks 90 and a rifle's reach). In pictures from outside the two looked alike, but the finger
  is asked to arch anyway (45 degrees at its middle joint, a fifth more at its tip): 119 degrees together, the pad
  0.8 mm off its mark. `index_arc` takes the tip's share as an optional third value; the pistols keep a half.
- **The Sniper's right thumb is fixed where it was** (attempt 2; `SNIPER_RIGHT` `thumb_turn`): searched afresh on the
  re-proportioned hand it lay a little less far over the stock's wrist, and the full check run failed HG1's test of a
  bot's thumb round the grip's left side (13 mm left of the middle, the test asks 15). Its turn is now the one the
  solve found before, as the AEG's and the pistols' are held.
- **The arms' build is three files** (attempt 2, the critic's check 7): `hold_tables.py` (each hold's marks, costs
  and limits), `hold_solve.py` (the hands placed and closed from them) and `arms.py` (the model, the clips and the
  export); the split moved code and changed none (the same build log from both).
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

- Aimed, the Cyber's right thumb lies a little flatter than the GBB's; on the Angled Grip's short tall end the ring
  and little fingers close under its foot (`docs/KNOWN_ISSUES.md` › Graphics).
- On the AEG's far side (a bot beside the player shows it; the player's own view never does) the left middle
  fingertip rests 13 mm past the handguard's end, and the fingers stand less evenly than on the Sniper and the SMG
  (the decision above; `docs/KNOWN_ISSUES.md` › Graphics).
- The skin's atlas has about 1,000 texels (of 1.27 million) claimed by two places on the hand, at the thumb's web; no
  seam shows in the pictures.
- Working the Sniper's bolt, the right elbow steps out a few centimetres over two frames where the sleeve would
  touch the stock; the elbow is below the view.
