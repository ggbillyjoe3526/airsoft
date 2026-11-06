# BL4 · Your first-person arms

**Review:** critic Retry 7/8 (attempt 10) · qa Pass (attempt 8) · performance Pass (attempt 10); the owner's ruling (2026-11-05
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

## What changed

- **The model** (`assets/models/arms/arms.glb`, `tools/blender/arms/`): the MakeHuman CC0 arm (`source/`) under a
  dark olive glove (skin + 1.1 mm) with a moulded knuckle guard, finger pads, a palm patch, cuff and
  strap, and a sleeve rolled over the cuff; mirrored for the right arm; the figures' bone names; 38,900 triangles, four plain
  materials. Each replica gets a clip `<id>_Hold` and an empty `Hold_<id>` at its origin.
- **The holds** (attempt 11), solved against each replica's model at rest (`pose.py`), none passing into it (the build
  refuses to write otherwise; gaps are the glove's skin to the replica, mm, first / middle / last section, from the
  build log with `BL_DEBUG`):
  - AEG Rifle: right hand high on the grip, the little finger wholly on it above the foot, the thumb round the grip's
    left side, index on the trigger (pad 1.4 mm off), wrist 22.1°; gaps index 6.0 / 3.7 / 2.3, middle 2.9 / 0.2 / -,
    ring 8.5 / 0.5 / 0.2, little 6.1 / 7.4 / 0.2, thumb 10.9 / 1.8 / 0.8.
  - AEG support hand: the palm cupping the handguard's underside at a fixed turn (fingers yawed 80°, pitched 25°),
    the forearm rising 33°, wrist 22.5°; each fingertip aimed at a point on the right side 10 mm ahead of its
    knuckle and 27.5 mm below the rail's top, swinging at most 8° sideways, its last joint bending 0.7 of its middle
    one (pads off their points: index 0.3, middle 3.7, ring 4.7, little 1.1 mm); gaps index 14.3 / 3.0 / 0.2, middle
    6.4 / 6.1 / 0.6, ring 3.0 / 0.8 / 2.6, little 0.3 / 2.7 / 0.7, thumb 25.6 / 3.4 / 0.1 (its root hangs below the
    handguard's left corner).
  - GBB Pistol: right hand alone, high on the back strap; the thumb tucked against the grip's left side and pointing
    forward and down along it, about 34° below the bore (seen from behind it no longer stands off the panel); the
    fingers closed under the guard; the trigger finger re-found after the palm seats (pad 2.5 mm off); gaps index
    3.3 / 2.1 / 0.6, middle 0.9 / 0.2 / 5.4, ring 4.5 / 0.4 / 2.0, little 3.7 / 1.2 / 0.1, thumb 10.2 / 0.9 / 0.0;
    wrist 17.3°. Its left arm hangs out of view (wrist 36.1°, never drawn).
  - Cyber Pistol: resized to the GBB's proportions (CZ1, PR #225); the GBB's marks, the web 2 mm further back and
    lower on its more upright back strap and the index knuckle 2 mm back (its trigger is 5 mm further from the back
    strap); trigger pad 0.3 mm off; gaps index 14.0 / 8.2 / 1.3, middle 2.3 / 3.1 / 0.2, ring 6.5 /
    5.2 / 0.8, little 7.8 / 2.0 / 0.0, thumb 8.2 / 1.4 / -; wrist 13.6°.
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

- Pistols one-handed for now, the left arm hidden; the Sniper Rifle shows no arms (`docs/DECISIONS.md` › Your
  first-person arms).
- Gloves `0x4c4638`, armour `0x242422`: the figures' gloves (BL10), from the owner's glove photos (dark olive,
  black moulded knuckles); the first build's coyote read as bare skin.
- The pistols' hip pose is unchanged: at the hip their grip and hand sit below the screen; the hand shows aimed.

## Known issues

- From the eye the support fingers show beyond the handguard's right edge (they lie on its outside); seen from the
  left the middle and ring tips still just show over the rail's top.
- First finger sections stand 4 to 8 mm off the grips (rifle ring, little and index; support index); the thumb roots
  8 to 11 mm.
- The glove has four plain materials: no woven, stitched or knitted surface detail yet (it has no UVs; a baked
  fabric normal map is the next step).
- The owner's holding photos show pistols two-handed, thumbs forward: the left hand's hold over the right is still
  to solve (first tries bent the left wrist past 80°).
- The Sniper Rifle's new chassis grip (BL5, about 6 cm deep, its back strap raked) needs its own hold.
- No arm clips for firing, reloading or the sniper's bolt.
