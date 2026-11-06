# BL4 · Your first-person arms

**Review:** critic Accept 7/8 (attempt 19) · qa Pass (attempt 19) · performance Pass (attempt 19); the owner approved
attempt 19 (2026-11-06 09:41: "just go with that"); the owner's ruling (2026-11-05
18:37, 19:46): keep going past the four attempts, the critic extremely harsh, merged only once he approves

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | 6/8 | Retry | Hands off the owner's photos (pistol thumbs, the rifle support hand), glove construction, wrists over 30°, the ASSETS row |
| 2026-11-05 | 2 | Claude (build thread) | 7/8 | Retry | Below the bar next to the photos: thumb heights, fingertips past the front strap, the slab knuckle shell and dice plates, a torn sleeve top; the owner's notes (16:30) |
| 2026-11-05 | 3 | Claude (build thread) | 7/8 | Retry | Below the stricter bar: torn web and patch edges, band-like knuckle shell, Cyber index short of the trigger, thumbs high; the owner's notes (17:54: tighter, the Cyber like the GBB) |
| 2026-11-05 | 4 | Claude (build thread) | 7/8 | Retry | Last attempt, stopped for the owner: finger first sections 7 to 11 mm off the grips, the Cyber thumb high beside the rear block, the support hand over the handguard's top (forearm rise 29°), slab knuckle shell, block-like plates, torn web and back-of-hand edges at large thumb twists |
| 2026-11-05 | 5 | Claude (build thread) | 7/8 | Retry | The owner's notes (18:37: keep going; the web's spike, the rifle thumb, the Cyber to be resized): support fingers over the rail, web and thumb gaps, the GBB middle finger under the guard, its wrap short, the knuckle shell |
| 2026-11-05 | 6 | Claude (build thread) | 6/8 | Retry | Extremely harsh (owner, 19:46): the pistol thumb a paddle beside the slide in the aimed view, support tips over the rail, the support thumb root off, rifle ring and little finger gaps, the trigger pad 2.2 mm off, the rifle wrist 27.7°, finger plates, tip caps and palm patch unlike photo 123404, a wedge in the sleeve, a mottled shell, the record's numbers |
| 2026-11-05 | 7 | Claude (build thread) | 6/8 | Retry | Support tips about 18 mm over the handguard's top (an overhand look from the left), the pistol thumb standing off the grip seen from behind, holes and a ragged band edge on the sleeve, first-section gaps (pistol index 9.4 and 10.7 mm), the record's numbers |
| 2026-11-05 | 8 | Claude (build thread) | 7/8 | Retry | Sleeve fixed; the GBB thumb still long and off the panel from behind, support fingers splayed and their middle sections 10 to 13 mm off the side, first-section gaps 6 to 11 mm, the rifle web flat, glove pads oversized and no fabric detail, QA not yet on the head |
| 2026-11-06 | 9 | Claude (build thread) | 7/8 | Retry | The GBB thumb's length and width now match photo 123843, but its tip hooked out to the left; support tip 5 mm over the rail; the rifle web one smooth bulge; pads long ovals; shell crease; no QA on the head |
| 2026-11-06 | 10 | Claude (build thread) | 7/8 | Retry | Support glove still over the rail from the left (the palm to sit lower round the handguard's lower corner); the rifle web, thumb bone and index bone one form; no knuckle rises or joint creases; the thumb plate long; no fabric maps; the record's GBB thumb wording |
| 2026-11-06 | 11 | Claude (build thread) | 7/8 | Retry | Support glove a gap above the palm and tips over the rail from the left; fingers fanned diagonally; no fabric maps; joint forms too faint; pads not round; GBB finger and thumb proportions off photo 123843; first-section gaps; QA not on the head |
| 2026-11-06 | 13 | Claude (build thread) | 7/8 | Retry | Support forearm at 40° met; pistol thumbs short of the frame's front and low in the owner's photos' terms, the GBB arm bent about 60°, the support palm showing from the eye with the thumb off the side, tips over the rail from the left; glove seams and the sleeve's weave reading as dots |
| 2026-11-06 | 14 | Claude (build thread) | 7/8 | Retry | GBB thumb high enough (0.09 G under the slide), but its middle finger lay straight out under the trigger guard; thumbs still short of the frame's front and sideways from the eye; pistol elbows near 40°; support palm and glove finish as attempt 13 |
| 2026-11-06 | 15 | Claude (build thread) | 6/8 | Retry | GBB middle finger wraps again but curls 20 to 28°; both pistol thumbs a paddle across the back of the frame from the eye; GBB elbow 32°; record numbers off; support hand and glove finish unchanged |
| 2026-11-06 | 18 | Claude (build thread) | 6/8 | Retry | Sniper support fingers fanned and over the fore-end's top; AEG support tips over the rail from the left; support thumbs steep (50 to 80° to the bore); the support palm faces the eye; GBB thumb short of the catch; sniper ring and thumb-root gaps; the wiki and changelog silent on the sniper (it is dev content, so they stay so) |

## What changed

- **The model** (`assets/models/arms/arms.glb`, `tools/blender/arms/`): the MakeHuman CC0 arm (`source/`) under a
  dark olive glove (skin + 1.1 mm) with a moulded knuckle guard, finger pads, a palm patch, cuff and
  strap, and a sleeve rolled over the cuff; mirrored for the right arm; the figures' bone names; 38,900 triangles, four
  materials. Each replica gets a clip `<id>_Hold` and an empty `Hold_<id>` at its origin.
- **The holds** (attempt 19), solved against each replica's model at rest (`pose.py`), none passing into it (the build
  refuses to write otherwise; gaps are the glove's skin to the replica, mm, first / middle / last section, from the
  build log with `BL_DEBUG`):
  - AEG Rifle: right hand high on the grip, the little finger wholly on it above the foot, the thumb over the top of
    the grip's left side (owner's photo 2, 2026-11-06), index on the trigger (pad 0.3 mm off), wrist 22.1°; gaps index
    6.0 / 3.7 / 2.3, middle 2.9 / 0.2 / -, ring 8.7 / 0.5 / 0.2, little 6.1 / 7.5 / 0.2, thumb 12.6 / 5.4 / 1.5.
  - AEG support hand: the palm under the handguard at a fixed turn (fingers yawed 60°, pitched 40°, rolled 20°), its
    centre 26 mm right of the handguard's centre line, so the thumb's base sits under its left side and the thumb
    presses on its side face a little above the centre line (the owner, 2026-11-06: gripping, not cradling); the
    forearm 41° off the bore seen from above and rising 38° (its sleeve kept 45 mm off the replica), wrist 25.6°; the
    fingers up the right side; gaps index 7.4 / 9.9 / 1.2, middle 6.6 / 12.9 / 0.9, ring 9.5 / 14.9 / 0.4, little
    8.5 / 0.5 / 3.5, thumb 5.2 / 0.7 / 2.2.
  - GBB Pistol: the Cyber's hold at its own marks (the owner, 2026-11-06 09:01: back to picture 6-gbb-thumb's grip): the
    web 3 mm further back and 1 mm lower than the Cyber's, behind the back strap's right corner; the thumb forward along
    the frame's left side at the grip's top swell, touching all along (tip 33 mm under the slide), each pose checked on
    the skinned glove; the fingers round the front strap; trigger pad 2.0 mm off; gaps index 4.3 / 1.8 / 0.9, middle 0.5
    / 0.3 / 2.9, ring 3.4 / 0.5 / 3.4, little 3.6 / 2.1 / 0.4, thumb 3.7 / 0.7 / 0.7. The arm comes up to it from below,
    rising 13° (reach 0.469 of 0.483), wrist 16.3°. Its left arm hangs out of view (wrist 36.1°, never drawn).
  - Cyber Pistol: resized to the GBB's proportions (CZ1, PR #225); the web 2 mm further back and lower on its more
    upright back strap, the index knuckle 2 mm back (its trigger is 5 mm further from the back strap); the thumb forward
    along the frame under its raised edge; trigger pad 1.3 mm off; gaps index 11.2 / 6.3 / 1.6, middle 0.6 / 3.0 / 0.6,
    ring 3.5 / 4.1 / 0.9, little 5.2 / 1.0 / 0.2, thumb 13.6 / 4.8 / -; the arm as the GBB's (rising 15°, reach 0.465),
    wrist 19.0°.
  - Sniper Rifle (new): the right hand round the stock's wrist, raked 54°, its marks set by the front strap and the
    thumb over the wrist's top onto its left side; the ring and little fingers closed at their outer joints onto the
    grip (`press`; the owner, 2026-11-06); index on the trigger (pad 0.2 mm off), wrist 23.8°; gaps index 10.4 / 7.5 /
    0.2, middle 1.5 / 0.8 / 0.4, ring 0.1 / 16.9 / 0.1, little 0.2 / 3.8 / 0.3, thumb 17.3 / 1.1 / 0.6. The support
    hand under the fore-end as the AEG's (yaw 50°, pitch 30°, roll 20°), its palm 34 mm right of the fore-end's
    centre line, the fingertips aimed higher up its right side and the little finger's 15 mm lower (tucked under),
    the thumb pressing on the left side face; forearm 40° off the bore from above, rising 29°, wrist 19.8°; gaps
    index 4.0 / 1.3 / 1.4, middle 4.1 / 2.9 / 0.4, ring 8.5 / 2.0 / 0.2, little 8.2 / 0.1 / 3.1, thumb 8.7 / 0.7 /
    0.4.
- **In the game** (`game/play/arms_view.gd`): ArmsView rides the replica in hand (ReplicaView's `Held.root`), its
  `Hold_<id>` on the replica's origin, posed by `<id>_Hold`; pressed depth, no shadow, out of the optic's view; the
  left arm hidden on one-handed replicas (ViewModelConfig.one_hand); a robot's colours (ViewModelConfig.robot_arms).
- **Attempt 2** (the critic's must-fix list):
  - Pistols: the thumb's root and the index knuckle placed at marks on each grip (`web`, `index`), the hand rolled
    about them to the straightest wrist; the thumb searched wider and twisted so it lies forward along the frame's
    left side under the slide (GBB wrist 20.8°, Cyber 12.6°).
  - AEG left hand: a search over the cupped hand's turn, under the handguard, fingers wrapping its right side, the
    forearm rising about 29° from below (wrist 18°); the right hand's wrist 24.9°.
  - Glove: one moulded knuckle shell, segmented finger and thumb plates, clean cuff edges.
  - The skinned-mesh relax eases the hand back before opening the thumb (it had swung the thumb straight out).
  - In game the arms take no shadows (hard patches on the sleeve were the sun's shadow on pressed depth).
- **Attempt 3** (the owner's notes, 16:30, and the critic's):
  - Every grip hold lays three marks (the thumb's root, the index and the little finger's knuckles) with a fitted
    turn (`pose.fit_turn`), so the knuckles run down the grip and the little finger closes on it; the middle, ring and
    little fingers swing up toward the index (`swing`). GBB wrist 23.7°, Cyber 25.1°.
  - AEG: the right hand higher on the grip, the little finger round its foot, the shoulder drawn in (wrist 22°); the
    support hand further back so its fingers rest on the handguard's right side (wrist 10.5°).
  - Glove: the knuckle shell over the knuckles only (24 mm deep, smoothed, padded rim); one rounded plate over each
    finger section, wrapping it; the sleeve ends 13 cm above the elbow and its cap moves with its rim (the torn top);
    39,338 triangles.
- **Attempt 4** (the owner's notes, 17:54, and the critic's):
  - Two last passes on the skinned mesh: each holding palm moves into the replica until its glove would first touch
    (`pose.press`), then every holding finger closes until its glove would first touch (`pose.tighten`); the build
    still refuses to write if anything passes into a replica. The log prints each hand's skin gaps with `BL_DEBUG`.
  - The Cyber's marks are the GBB's laid on its own grip; index on the trigger (0.2 mm), wrist 15.3°, its finger gaps
    like the GBB's; its thumb rides high beside the rear block (lower, the frame leaves it no room without dropping
    the whole hand, which made the two grips look different).
  - Glove: four taller knuckle domes on a thinner shell, lifted off the hand; the plates lifted with softer ends; the
    palm patch off the heel; a larger velcro tab on the back of the cuff. 39,386 triangles.
- **Attempts 5 to 7** (the owner's notes 18:37, 19:41, 19:46 and the critic's):
  - Replicas are fitted at rest: the glTF import left the replica's Fire clip on (the GBB's slide back 25 mm).
  - The web of the hand smoothed (`glove.smooth_web`): the pointed spike between thumb and index is gone.
  - The pistol thumb's search tries knuckle bends too (`THUMB_BENDS`), so it comes round the back strap's corner and
    lies down the grip's side instead of standing out beside the slide in the aimed view.
  - Fingers tighten one at a time and wrap their first sections down (`pose.tighten`, `pose.wrap`); the support
    hand's fingers never rise further over the handguard's top (`tips_below`).
  - The glove after photo 123404: one smooth domed knuckle shell with a raised border, a small oval pad on the back of
    each finger's first section and the thumb's, plain fingertips, a rounded palm patch. 38,170 triangles.
  - The sleeve follows the forearm and upper arm only (it twisted with the wrist and folded into a dark wedge along
    the forearm in the pistol's aimed view); its normals smoothed.
- **Attempt 8** (the critic's attempt 7 list):
  - Support hand: steeper, the knuckles rose up the side and the fingers stood over the top; flatter, the wrist bent
    past 30° (twenty placements tried). Fixed at 80° / 48°, each finger then reaches for its own point on the right
    side (`Hand.onto` with `couple`, `TIP_COUPLE`): curled like a relaxed finger, never a claw.
  - Sleeve: its cuff was cut 4 mm off where its faces were chosen, so some cuff edges counted as the shoulder's
    opening and its cap closed over them with 87 long slivers through the forearm: the holes in the pistol's aimed
    view, the ragged cuff and the void at it. The sleeve is now cut at its end and at its band's edge (a clean ring).
  - Pistol thumb tip lower and held closer (`thumb_at`, `thumb_hug` 6).
  - Glove: four soft lobes in the knuckle dome with seams between, a sunken centre in each finger pad.
- **Attempt 9** (the critic's attempt 8 list):
  - Support fingers held together (each swings at most 8° sideways reaching its point): curled side by side, the
    tips at the rail's edge.
  - The web between thumb and index: the glove itself bulges up to 4 mm over the muscle there (`glove.hand_forms`),
    fullest toward the index, so it reads rounded, not as a flat sheet.
  - The thumb's glove 1.5 mm fuller over its last two sections; the finger pads smaller (24° round the finger),
    1.2 mm high, their hollow wider; the knuckle shell's lobes softer (2.5 mm).
- **Attempt 10** (the critic's attempt 9 list): the thumb's glove fullness 0.8 mm (at 1.5 the thumb found no room on
  the panel and hooked out to the left, its pad facing the eye); round finger pads (half to 86 % of the first bone,
  28° round it); the knuckle shell's lobes 1.5 mm and its sides cast straighter (a crease at its index corner).
- **Attempt 19** (pictures in review20; the owner, 2026-11-06 09:01 to 09:08: attempt 18's GBB grip, the web on the back
  strap's centre line, "worse", back to the grip of its earlier picture 6-gbb-thumb, the web behind the back strap's
  right corner; the arm took too much of the screen and was still straight; "only the hands and part of the wrist should
  be visible, not the forearm", with Valorant's pistols as the look): the GBB grip back to 6-gbb-thumb's. Both pistols
  sit higher and nearer the middle at the hip (`ViewModelConfig.hip` (0.05, -0.07, -0.34), was (0.12, -0.15, -0.34); the
  arms' HOLDS match), so the hand shows with the wrist at the screen's bottom edge, and aimed 0.25 m ahead of the eye
  (was 0.36), near enough that the forearm drops out of view under the hand. The arm comes up to the grip from below:
  its shoulder moved in and down (`shoulder`, `drop`), the forearm rising 13° (GBB) and 15° (Cyber), the wrist 16.3° and
  19.0° (was 6.9° and 9.2°): with the forearm off screen the bend shows only at the cuff, and the owner took it on these
  pictures (09:41: "just go with that"). The sight tests look from the new distance.
- **Attempt 18** (the owner, 2026-11-06 04:24 to 05:15: the sniper's hold shots, the GBB thumb more forward onto
  the bump behind the trigger guard, the sniper's ring and little fingers and both rifles' support thumbs pressing on
  the rifle): the Sniper Rifle's hold (above); `Hand.press` closes a settled finger's outer joints onto the replica;
  the support thumbs aimed at the side face above the centre line; `tip_drop` lowers one support fingertip's aim.
  `Hand.thumb` can check its poses on the skinned glove (`thumb_verify`, the GBB's): the bones' sampled surface had
  passed forward GBB thumbs whose glove cut into the frame's top rear corner, which the relax pass then bent up past
  the slide or out to the left, seen from the eye. With the check, no thumb from the web behind the back strap
  reaches further forward than the grip's top swell. So the GBB's web moves onto the back strap's centre line
  (the owner, 07:10: "move the thumb as needed"), its thumb's root at the frame's left rear corner, and the thumb
  lies forward along the frame, about 1.5 cm short of the catch (further, its glove cuts into the frame); its
  fingers' first sections stand 12 to 21 mm off the grip's right side.
- **Attempt 17** (the owner, 2026-11-06 03:58, on attempts 15 and 16: the Cyber good, the GBB thumb wrong, the
  support thumb to rest on the rifle): the GBB takes the Cyber's hold at its own marks (the raised GBB hand of
  attempts 14 to 16 is undone; the two grips now look alike from the eye), both arms at 97 % of their reach; the
  support palm 18 mm further left under the handguard (`forward` 34 mm, from 52), so the thumb lies on it along
  its lower left side (sections 9.9 / 0.7 / 0.7 mm off, from 23 / 11 / 1). `thumb_wide` (off) lets the support
  thumb search as widely as a grip's.
- **Attempt 16** (the critic's attempt 15 list): both pistols' web on the back strap's centre line, not 12 mm to its
  right, so the thumb's base sits on the frame's left side and the thumb lies forward along it (from the eye it had
  stood out across the back strap), and the fingers close further round the front strap; the shoulder drawn back
  to 0, -0.145, 0.11 (reach 0.467, the elbow about 30°). The fingers' first sections now stand 9 to 21 mm off the
  grip's right side: the hand turns about the new web.
- **Attempt 15** (the critic's attempt 14 list): the GBB's finger marks back down 5 to 7 mm while its web stays
  high (raised together, the middle finger lay straight out under the trigger guard); both pistol arms reach 96 to
  97 % (the shoulder drawn back `shoulder` 0, -0.14, 0.105); the GBB's elbow came to 32°.
- **Attempt 14** (the critic's attempt 13 list): the GBB's marks 1.5 cm higher (web, index, little finger), so the
  hand sits up at the beavertail and the thumb lies right under the slide; both pistols' arms less bent (reach 94 to
  95 %, the elbow about 40°, from 86 %); `thumb_curl` bounds how far a grip's thumb closes onto the frame. Tried and
  left: the support palm flatter (within 20° of facing up) needs a 46 to 48° wrist at the 40° forearm, over the
  owner's 30° limit; the GBB thumb's tip cannot reach further forward than 5 cm ahead of the back strap without
  passing into the frame (its root sits at the web).
- **Attempt 13** (the owner's notes, 2026-11-06 01:40 to 01:59, and his eight hold photos): every thumb higher
  (`thumb_pull` makes the tip's target count over the hug); the pistol arm bent from a shoulder moved forward and up;
  the support forearm at 40° from above (`plan`, scored in `elbow_for` and `cup`), the cup search keeping the
  forearm clear of the replica (`FOREARM_CLEAR`); the support's tip height check taken level with the hand.
  `BL_G_<KEY>` overrides the support hand's spec alone.
- **Attempt 12** (the critic's attempt 11 list): the glove, its moulded parts and the sleeve carry a woven normal
  map (`fabric.py`: a 256 px plain-weave tile, threads 1 mm on the glove, finer on the shell, coarser on the
  sleeve, over UVs unwrapped by angle and scaled to the world; Godot extracts it as `arms_ArmsWeave.png`); the
  support palm rests on the handguard's underside (`standoff` 0) at a fixed roll of 20° (rolled less the thumb
  leaves the left side), its fingertips aimed straight up the side (5 mm ahead of the knuckle, 25.5 mm below the
  top), so none shows over the rail from the left; rounder finger pads (56 to 84 % of the first bone, 34° round it);
  the joints' rises 2.0 and 1.4 mm, their creases 1.5 mm.
- **Attempt 11** (the critic's attempt 10 list): the support hand turned flatter (fingers pitched 25°, not 48°) and
  seated further back (`forward` 52 mm), so the palm cups the handguard's underside round its lower left corner and
  the knuckles sit under its lower right one; the shoulder higher (`shoulder` -0.02, 0.12, -0.08) so the forearm
  comes in at about 33° and the wrist stays at 23°; each fingertip aimed 10 mm ahead of its knuckle and 27.5 mm
  below the rail's top. The glove's surface carries the hand's forms (`glove.hand_forms`): the web muscle (4 mm,
  fuller toward the index), the thumb's bone as its own ridge beside it (1.8 mm), the index bone's edge (1.2 mm),
  a rise over each middle and last finger joint (1.1 and 0.7 mm) and a crease across the palm's side of each
  (0.7 mm). The thumb's plate is gone (photo 123404's thumb is plain). `BL_SEARCH` overrides the cup's turn range.
- `Hand.seat` can keep the whole hand bone clear (the left hand's knuckles and thumb heel); `Hand.thumb` lets the
  thumb's root rest on the grip and can hug its whole length to the replica.

## Decisions

- Pistols one-handed for now, the left arm hidden; the Sniper Rifle held as the AEG is (`docs/DECISIONS.md` › Your
  first-person arms).
- Gloves `0x4c4638`, armour `0x242422`: the figures' gloves (BL10), from the owner's glove photos (dark olive,
  black moulded knuckles); the first build's coyote read as bare skin.
- The pistols at the hip sit higher and nearer the middle, aimed 0.25 m ahead of the eye (the owner, 2026-11-06:
  hand and wrist in view, never the forearm); the AEG and Sniper Rifle are unchanged.

## Known issues

- From the eye the support fingers show beyond the handguard's right edge (they lie on its outside); seen from the
  left the middle and ring tips still just show over the rail's top.
- First finger sections stand 3 to 11 mm off the grips (rifle ring, little and index; Cyber index 11.2; sniper index
  10.4); support fingers' middle sections 10 to 15 mm off the AEG handguard's side; thumb roots 4 to 17 mm (sniper
  17.3, Cyber 13.6, AEG 12.6).
- The GBB thumb's tip stops about 1.5 cm short of the catch behind the trigger guard the owner pointed to: reaching
  it, the glove cuts into the frame's top rear corner (the owner kept this grip, 2026-11-06 09:01).
- The glove's weave is one tile for all its parts: no stitching, knit bands or seams yet.
- The owner's holding photos show pistols two-handed, thumbs forward: the left hand's hold over the right is still
  to solve (first tries bent the left wrist past 80°).
- No arm clips for firing, reloading or the sniper's bolt.
