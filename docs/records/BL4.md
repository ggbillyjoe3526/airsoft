# BL4 · Your first-person arms

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | pending | pending | – |

## What changed

- **The model** (`assets/models/arms/arms.glb`, `tools/blender/arms/`): the MakeHuman CC0 arm (`source/`) under a
  dark olive glove (skin + 1.1 mm) with a moulded knuckle guard, finger and thumb pads, a palm patch, cuff and
  strap, and a sleeve rolled over the cuff; mirrored for the right arm; the figures' bone names; 39,646 triangles, four plain
  materials. Each replica gets a clip `<id>_Hold` and an empty `Hold_<id>` at its origin.
- **The holds**, solved against each replica's model (`pose.py`), none passing into it (the build refuses to write
  otherwise):
  - AEG Rifle: right hand round the grip, index on the trigger (0.5 mm), wrist 30°; left hand round the handguard's
    middle (y 0.19), fingers up its right side, thumb along its left side, wrist 20°.
  - GBB Pistol: right hand alone, fingers round the front strap, index on the trigger (1.1 mm), thumb along the frame,
    wrist 33°.
  - Cyber Pistol (fitted to BL6's rebuilt model): right hand alone, index into the guard, thumb curled behind, wrist
    32°.
- **In the game** (`game/play/arms_view.gd`): ArmsView rides the replica in hand (ReplicaView's `Held.root`), its
  `Hold_<id>` on the replica's origin, posed by `<id>_Hold`; pressed depth, no shadow, out of the optic's view; the
  left arm hidden on one-handed replicas (ViewModelConfig.one_hand); a robot's colours (ViewModelConfig.robot_arms).
- `Hand.seat` can keep the whole hand bone clear (the left hand's knuckles and thumb heel); `Hand.thumb` lets the
  thumb's root rest on the grip and can hug its whole length to the replica.

## Decisions

- Pistols one-handed for now, the left arm hidden; the Sniper Rifle shows no arms (`docs/DECISIONS.md` › Your
  first-person arms).
- Gloves `0x4c4638`, armour `0x242422`: the figures' gloves (BL10), from the owner's glove photos (dark olive,
  black moulded knuckles); the first build's coyote read as bare skin.
- The pistols' hip pose is unchanged: at the hip their grip and hand sit below the screen; the hand shows aimed.

## Known issues

- The owner's holding photos show pistols two-handed, thumbs forward: the left hand's hold over the right is still
  to solve (first tries bent the left wrist past 80°).
- The Sniper Rifle's new chassis grip (BL5, about 6 cm deep, its back strap raked) needs its own hold.
- No arm clips for firing, reloading or the sniper's bolt.
