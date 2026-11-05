# BL4 · Your first-person arms

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | 6/8 | Retry | Hands off the owner's photos (pistol thumbs, the rifle support hand), glove construction, wrists over 30°, the ASSETS row |
| 2026-11-05 | 2 | Claude (build thread) | 7/8 | Retry | Below the bar next to the photos: thumb heights, fingertips past the front strap, the slab knuckle shell and dice plates, a torn sleeve top; the owner's notes (16:30) |
| 2026-11-05 | 3 | Claude (build thread) | 7/8 | Retry | Below the stricter bar: torn web and patch edges, band-like knuckle shell, Cyber index short of the trigger, thumbs high; the owner's notes (17:54: tighter, the Cyber like the GBB) |
| 2026-11-05 | 4 | Claude (build thread) | pending | pending | – |

## What changed

- **The model** (`assets/models/arms/arms.glb`, `tools/blender/arms/`): the MakeHuman CC0 arm (`source/`) under a
  dark olive glove (skin + 1.1 mm) with a moulded knuckle guard, finger and thumb pads, a palm patch, cuff and
  strap, and a sleeve rolled over the cuff; mirrored for the right arm; the figures' bone names; 39,646 triangles, four plain
  materials. Each replica gets a clip `<id>_Hold` and an empty `Hold_<id>` at its origin.
- **The holds**, solved against each replica's model (`pose.py`), none passing into it (the build refuses to write
  otherwise):
  - AEG Rifle: right hand high on the grip, little finger round its foot, index on the trigger (0.4 mm), wrist 18.7°;
    left hand under the handguard's middle (y 0.19), fingers resting on its right side, thumb along its left side,
    wrist 10.7°.
  - GBB Pistol: right hand alone, high on the back strap, fingers up under the guard, index on the trigger (0.7 mm),
    thumb along the frame, wrist 23.7°.
  - Cyber Pistol (fitted to BL6's rebuilt model): right hand alone, the GBB's hold on its grip, index on the trigger
    (0.2 mm), thumb high beside the rear block, wrist 15.3°.
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
- `Hand.seat` can keep the whole hand bone clear (the left hand's knuckles and thumb heel); `Hand.thumb` lets the
  thumb's root rest on the grip and can hug its whole length to the replica.

## Decisions

- Pistols one-handed for now, the left arm hidden; the Sniper Rifle shows no arms (`docs/DECISIONS.md` › Your
  first-person arms).
- Gloves `0x4c4638`, armour `0x242422`: the figures' gloves (BL10), from the owner's glove photos (dark olive,
  black moulded knuckles); the first build's coyote read as bare skin.
- The pistols' hip pose is unchanged: at the hip their grip and hand sit below the screen; the hand shows aimed.

## Known issues

- The AEG's right thumb wraps the grip's left side rather than resting up by the selector: every try to reach the
  selector stood the thumb up over the back strap (a common real grip either way; default kept).
- The rifle's support forearm rises about 29°, under the 40° to 70° of the owner's photos: not tuned further this
  attempt (the left shoulder's place and the elbow's drop set it, `GUARD` in `arms.py`).
- The owner's holding photos show pistols two-handed, thumbs forward: the left hand's hold over the right is still
  to solve (first tries bent the left wrist past 80°).
- The Sniper Rifle's new chassis grip (BL5, about 6 cm deep, its back strap raked) needs its own hold.
- No arm clips for firing, reloading or the sniper's bolt.
