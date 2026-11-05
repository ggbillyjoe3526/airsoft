# BL4 · Your first-person arms

**Review:** critic Retry 6/8 (attempt 6) · qa Pass (attempt 4) · performance Pass (attempt 4); the owner's ruling (2026-11-05
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

## What changed

- **The model** (`assets/models/arms/arms.glb`, `tools/blender/arms/`): the MakeHuman CC0 arm (`source/`) under a
  dark olive glove (skin + 1.1 mm) with a moulded knuckle guard, finger and thumb pads, a palm patch, cuff and
  strap, and a sleeve rolled over the cuff; mirrored for the right arm; the figures' bone names; 38,170 triangles, four plain
  materials. Each replica gets a clip `<id>_Hold` and an empty `Hold_<id>` at its origin.
- **The holds** (attempt 7), solved against each replica's model at rest (`pose.py`), none passing into it (the build
  refuses to write otherwise; gaps are the glove's skin to the replica, from the build log with `BL_DEBUG`):
  - AEG Rifle: right hand high on the grip, the little finger wholly on it above the foot, the thumb round the grip's
    left side, index on the trigger, wrist 22.1°; left hand low under the handguard, its fingertips on the right side
    (0.2 to 0.5 mm), the forearm rising 57°, wrist 0.5°.
  - GBB Pistol: right hand alone, high on the back strap; the thumb round the back strap's corner and down the grip's
    left side, as photo 123843; fingers closed under the guard (middle 0.0, ring 0.3, little finger 0.2 mm at their
    middle and last sections); the trigger finger re-found after the palm seats (pad 0.8 mm off); wrist 16.8°.
  - Cyber Pistol: waits for its resize to the GBB's size (the owner, 18:37); built with `BL_FORCE` meanwhile.
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
- `Hand.seat` can keep the whole hand bone clear (the left hand's knuckles and thumb heel); `Hand.thumb` lets the
  thumb's root rest on the grip and can hug its whole length to the replica.

## Decisions

- Pistols one-handed for now, the left arm hidden; the Sniper Rifle shows no arms (`docs/DECISIONS.md` › Your
  first-person arms).
- Gloves `0x4c4638`, armour `0x242422`: the figures' gloves (BL10), from the owner's glove photos (dark olive,
  black moulded knuckles); the first build's coyote read as bare skin.
- The pistols' hip pose is unchanged: at the hip their grip and hand sit below the screen; the hand shows aimed.

## Known issues

- The support fingertips still reach a few millimetres over the handguard's top seen from the left: a cupped hand's
  fingers are longer than the 48 mm side; the build keeps them as low as they rest.
- First finger sections stand 6 to 9 mm off the grips (rifle ring and little fingers, the pistol's ring); the rifle's
  thumb root and the support thumb root 8 to 11 mm.
- The owner's holding photos show pistols two-handed, thumbs forward: the left hand's hold over the right is still
  to solve (first tries bent the left wrist past 80°).
- The Sniper Rifle's new chassis grip (BL5, about 6 cm deep, its back strap raked) needs its own hold.
- No arm clips for firing, reloading or the sniper's bolt.
