# BL4 · Your first-person arms

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | 6/8 | Retry | Hands off the owner's photos (pistol thumbs, the rifle support hand), glove construction, wrists over 30°, the ASSETS row |
| 2026-11-05 | 2 | Claude (build thread) | pending | pending | – |

## What changed

- **The model** (`assets/models/arms/arms.glb`, `tools/blender/arms/`): the MakeHuman CC0 arm (`source/`) under a
  dark olive glove (skin + 1.1 mm) with a moulded knuckle guard, finger and thumb pads, a palm patch, cuff and
  strap, and a sleeve rolled over the cuff; mirrored for the right arm; the figures' bone names; 39,646 triangles, four plain
  materials. Each replica gets a clip `<id>_Hold` and an empty `Hold_<id>` at its origin.
- **The holds**, solved against each replica's model (`pose.py`), none passing into it (the build refuses to write
  otherwise):
  - AEG Rifle: right hand round the grip, index on the trigger (1.3 mm), wrist 24.9°; left hand under the
    handguard's middle (y 0.19), fingers wrapping its right side, thumb along its left side, wrist 18°.
  - GBB Pistol: right hand alone, high on the back strap, index on the trigger (0.3 mm), thumb along the frame,
    wrist 20.8°.
  - Cyber Pistol (fitted to BL6's rebuilt model): right hand alone, index on the trigger (4.9 mm), thumb along the
    frame, wrist 12.6°.
- **In the game** (`game/play/arms_view.gd`): ArmsView rides the replica in hand (ReplicaView's `Held.root`), its
  `Hold_<id>` on the replica's origin, posed by `<id>_Hold`; pressed depth, no shadow, out of the optic's view; the
  left arm hidden on one-handed replicas (ViewModelConfig.one_hand); a robot's colours (ViewModelConfig.robot_arms).
- **Attempt 2** (the critic's must-fix list):
  - Pistols: the thumb's root and the index knuckle placed at marks on each grip (`web`, `index`), the hand rolled
    about them to the straightest wrist; the thumb searched wider and twisted so it lies forward along the frame's
    left side under the slide (GBB wrist 20.8°, Cyber 12.6°).
  - AEG left hand: a search over the cupped hand's turn, under the handguard, fingers wrapping its right side, the
    forearm rising about 29° from below (wrist 18°); the right hand's wrist 24.9°.
  - Glove: one moulded knuckle shell, segmented finger and thumb plates, clean cuff edges; 39,950 triangles.
  - The skinned-mesh relax eases the hand back before opening the thumb (it had swung the thumb straight out).
  - In game the arms take no shadows (hard patches on the sleeve were the sun's shadow on pressed depth).
- `Hand.seat` can keep the whole hand bone clear (the left hand's knuckles and thumb heel); `Hand.thumb` lets the
  thumb's root rest on the grip and can hug its whole length to the replica.

## Decisions

- Pistols one-handed for now, the left arm hidden; the Sniper Rifle shows no arms (`docs/DECISIONS.md` › Your
  first-person arms).
- Gloves `0x4c4638`, armour `0x242422`: the figures' gloves (BL10), from the owner's glove photos (dark olive,
  black moulded knuckles); the first build's coyote read as bare skin.
- The pistols' hip pose is unchanged: at the hip their grip and hand sit below the screen; the hand shows aimed.

## Known issues

- The AEG's right thumb wraps the grip's left side rather than resting up by the selector: from the hand's place on
  the grip the selector is about 5 cm higher, and every try stood the thumb up over the back strap (a common real
  grip either way; default kept).
- The rifle's support forearm rises about 29°, under the 40° to 70° of the owner's photos: not tuned further this
  attempt (the left shoulder's place and the elbow's drop set it, `GUARD` in `arms.py`).
- The owner's holding photos show pistols two-handed, thumbs forward: the left hand's hold over the right is still
  to solve (first tries bent the left wrist past 80°).
- The Sniper Rifle's new chassis grip (BL5, about 6 cm deep, its back strap raked) needs its own hold.
- No arm clips for firing, reloading or the sniper's bolt.
