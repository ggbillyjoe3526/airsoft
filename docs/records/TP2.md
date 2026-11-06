# TP2 · Rifles held with the stock in the shoulder

**Review:** see the pull request's Review line

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure and hit tests green locally | Retry 6/8 | head upright, eye over the sights; QA: a pop on a rifle-pistol switch |
| 2026-11-05 | 2 | Claude (build thread) | 279 figure and hit tests green locally | Accept 8/8 | – |
| 2026-11-06 | 3 | Claude (build thread) | 341 figure, hit, parts and throw tests green locally | Retry 6/8 | no TP3 test; KNOWN_ISSUES and README rows |
| 2026-11-06 | 4 | Claude (build thread) | grip fit tests added (fail with grip_fit empty) | Accept 8/8 | – |

## What the owner asked (2026-11-05 16:21)

"Bots seem to hold their replicas too high. In particular the rifles; they should hold it like a real weapon. The
buttstock should rest at the figure's armpit. This is realistic and natural. Make sure all bots and the player figure
do this."

## Cause

The aim clips put the rifle's butt about 8 cm above the right shoulder's joint and well ahead of it, up by the cheek.

## What changed

- **`FigureReady.shoulder`**, run by `FigureBend` after the aim and before the high ready: the rifle's butt (the
  middle of the replica's last `shoulder_butt_depth`, found by `FigureHands` as each body takes its replicas) is moved
  onto the shoulder pocket, `FigureConfig.shoulder_pocket` from `shoulder_bone`'s joint (4 cm in, 8 cm ahead) turned
  with the chest (so a lean or a steep aim keeps it on the shoulder), the replica's aim kept; both arms reach for their
  hands' new places by the same two-bone IK as the high ready.
- **`FigureBody`** sets how far: the aim's share, for a rifle in the hand (not a pistol, not hanging from a hit call,
  not mid-switch), less the high ready, eased over `settle_shoulder` (`shoulder_rifle` scales it; 0 turns it off).
- **The cheek on the stock** (`HitFit.cheek_turn`): aiming a rifle, the head bows `HitConfig.cheek_bow` (0.3 rad)
  forward and tilts `cheek_cant` (0.2 rad) right about the neck's joint, so the eye sits over the sights. `FigureBend`
  draws it (eased with the pistol's clips over a switch) and `HitPose` bows the hit volume's head alike, so the hit
  area stays on the drawn head.
- **The fists on the grips** (attempt 3, from the BP4 bug pass: a pistol sat on top of the fists, the AEG's grip ahead
  of the right fist): human.json's `replicaOnGrip` was set for the first replica models, and the rebuilt ones' grips
  sit elsewhere. `FigureReady.fit_grip`, before the shoulder, moves the right hand `FigureConfig.grip_fit` along the
  replica (rifle 3.5 cm up and 2 cm back, pistol 2.2 cm up), both hands for a pistol (not the left in a reload, which
  takes the magazine out), and `FigureHands` shifts the replica the other way in the hand, so it stays where the clips
  put it and the left hand stays on the handguard. `raise_down` 0.2 → 0.205 m so the higher right hand stays under the
  head at the high ready.
- Tests for the fit: `test_grip_fit_qa.gd` (the fist reaches grip_fit, the replica stays, the left hand stays on a
  rifle and goes with the right on a pistol but not in a reload; none holstered or hanging).
- Tests: `test_figure_raise.gd` (the butt in the pocket, leaning both ways too; a pistol not drawn in; the cheek on a
  rifle only; a switch lets go of the shoulder before the pistol comes; the level rifle's reach and height now 0.62 m
  and 1.42 m); the reload clip timing test in `test_figure_hands.gd` turns the shoulder off to read the clip's own
  hand (put back after each test).

## Decisions

- **The hold is drawn only, like the high ready**; the head's bow is the one part the hit volume follows, because the
  head moves up to 9 cm with it (test_hit_fit's 4 cm joint tolerance).
- **The high ready wins**: the shoulder gives way as the raise rises, so at a wall the muzzle still clears a crate.
- **A switch lets go first**: the shoulder eases to none while the old replica is put away, so the butt's place never
  jumps when the replica in the hand changes.
