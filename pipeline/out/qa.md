Task: HC1 · QA commit none (nothing committed, as briefed; head 13f0b7c) · Verdict: Pass

Blocking: none.
Advisory:
- tests/unit/test_hit_call_arm.gd (_globals, `if bone < 0: continue`): a track whose bone name stops matching is skipped, so that bone sits at rest and the arm at rest (straight, flat hand) would pass the held checks. The tests fail on the old glbs today, so they do measure; a one-line `assert_true(sk.find_bone("Hand_L") >= 0)` per kind would guard a rename. Judgment.
- The held-pose limits are loose for the hand (30 deg curl allowed, 6 measured) but close for the elbow (20 allowed, 15 measured on HitCall, 14.0 to 15.9 on WalkOff). Fine today; a re-tune of ARM/FOREARM past 5 deg trips it by design.
- Nothing pins the head clearance the OUT swing exists for (hand not crossing the visor); it is a look-and-see item for the owner (hit0z/hit1z pictures).

call.py checked (human and robot glbs read back with glb.py, compared with base_*.glb):
- Bones outside the left arm and fingers: every track equal to the old glb (np.array_equal on times and values), HitCall and WalkOff, both figures; no track added or dropped. Changed tracks: 18 per clip (3 arm + 15 finger), all *_L arm or finger bones.
- Key counts: HitCall 31 each, unchanged; WalkOff fingers 2 -> 24 keys (the arm's times), arm 24 -> 24.
- Rotation tracks: unit length to 1e-4, no sign flip between neighbouring keys (dot > 0 everywhere), from the explicit pass after the loop.
- Curve: De Casteljau with the same share s for both levels; s=0 gives the old hold (RAISE_FROM key equals the old pose, keys before it are the old clip's own), s=1 gives the target, so no pop at RAISE_TO; fingers/hand use the OPEN_BY share and reach the target by frame 7. arm2.py per frame (human HitCall): elbow 51 at f02 falling to 15.0 from f14, wrist 5.2, curl 49 at f00 to 6.1 by f07; no frame-to-frame jump beyond the old clip's own f01 to f02 elbow step (34 to 51, before the raise starts, unchanged old data).
- Finger parent chain: Thumb1 keeps its root; each other joint turns by its least swing to the bone before it, composed with the straightened parent (parent updated with the STRAIGHTEN-blended `out`, not the fully straight one); rest bone axes are +Y for Index2/3, Thumb2, Pinky2 in both figures, so qrot(.., UP) is right and matches the test's TIP.
- Joins: HitCall's last key equals WalkOff's first (elbow 15.0, wrist 5.2, curl 6.1 both); WalkOff's sway is sin(2 pi t / span), 0 at both ends, so it loops/joins without a pop.

Tests (godot, run from W; gdlint tests/unit/test_hit_call_arm.gd tools/gait_pictures.gd: no problems):
- 4 files, 45 tests, 45 passing, 898 asserts, 3.3 s wall; test_hit_call_arm.gd alone 2 tests, 404 asserts, 0.46 s; no orphan, leak or error lines.
- test_hit_call_arm.gd:36 (HitCall) and :56 (WalkOff) · bones posed from the clips' own tracks over the skeleton rest, per 1/30 s, elbow/wrist/curl measured on joint positions · fails on the old glbs: run in a copy of W (scratchpad/wt_old) with base_human.glb and base_robot.glb, 2 of 2 tests fail: HitCall elbow folded 106-130 deg at 0.17-0.33 s, wrist 37 deg at 0.97-1.0 s, hand open and WalkOff held-pose failures (156 elbow, 156 wrist, 156 curl failed asserts, 92 curl on the way up, 108 wrist on the way up).
- Bone placing in the test matches call.py's pose maths (Basis from the track quaternion times the rest scale, parent chain by bone index): same readings as arm2.py to the degree on spot frames.
Not tested: how the arm looks (needs a display; pictures were filmed by the worker); head clearance in motion.
