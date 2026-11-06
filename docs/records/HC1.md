# HC1 · The hit call's raised arm

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure tests (94 pass) | Retry 6/8 (QA Pass, performance Pass) | the fingers still curled 52-55° (a claw); the raise kept the old path, the wrist cocked over 30° for 5 frames and the elbow whipping 124° to 17° in 4 frames, the hand saluting past the visor; no test; no named reference |
| 2026-11-05 | 2 | Claude (build thread) | figure tests, test_hit_call_arm (fails on the old clips) | Retry 7/8 | the raise swept the hand out sideways to 0.6 m and back (a shrug), the fingers still curled at its widest; QA and performance reports were attempt 1's |
| 2026-11-05 | 3 | Claude (build thread) | figure tests, test_hit_call_arm (QA: 45 pass) | Accept 8/8 (QA Pass, performance Pass) | – |

## Why

The owner (2026-11-05): "Arms, wrist, hands need to be straighter when held up during the hit animation. Right now
the wrist is at a strange unnatural angle." Measured on the HitCall clip: the raised left arm held the elbow bent
70° out to the side, the forearm leaning in behind the head and the wrist cocked 37° (WalkOff the same, 73° and 40°).

## What changed

- `tools/blender/bot-figure/gait/call.py` (numpy, no Blender) remakes the left arm and hand of HitCall and WalkOff;
  every other bone keeps its keys. Spliced into `human.glb` and `robot.glb` by `splice.mjs`, clips only.
  - **The held arm:** the upper arm, forearm and hand each turned by its least turn (keeping its roll) to point straight
    up a little out and forward: the elbow 15°, the wrist 5° back with the palm ahead, the hand 0.51 m over the
    shoulder (was 0.44 m).
  - **The open hand:** each finger joint straightened 85% of the way towards the bone before it (the first joints
    towards the hand's own line, so the fingers lie together), the thumb's root kept beside the hand: no joint over
    6° (was up to 52°).
  - **The raise:** the old clip's hold on the replica until frame 2, then by frame 14 (12 frames, eased) a curve that
    swings the arm up, forward and a little out (the hand at most 0.41 m to the side), so the hand never crosses the
    visor; the hand rises every frame; the wrist eases from the hold's 22° to 5° and the elbow from 51° to 15° with no
    fold on the way. The hand opens sooner, by frame 7 (no finger joint over 20° from then).
  - **The walk off:** the same held arm, swaying 3-4° with the walk.
- `tests/unit/test_hit_call_arm.gd`: both figures' HitCall and WalkOff read from their tracks: held, the elbow 20° or
  less, the wrist 10° or less and every finger joint (the knuckle too) 30° or less; on the way up the wrist never over
  30°, the elbow never over 90° and, from frame 7, no finger joint over 20°. It fails on the old clips.
- `tools/gait_pictures.gd` films the hit call (`call`), the walk off (`off`) and a crouched still figure (`kneel`).
- Before and after pictures: `/mnt/project-files/art/animation/hit-call/`.

## Reference

The owner's anatomy study (`/mnt/project-files/art/references/arm-hand-anatomy.png`): the "Open hand (relaxed)" pose
(fingers together and nearly straight, a light bend at each joint, the thumb alongside) for the hand, and the straight
arm of its layers comparison (the hand continuing the forearm's line at the wrist) for the arm. Compared: the hand's
line through the wrist (5° here, about the study's), the fingers' bend per joint (6° here, a few degrees there), the
hand's length against the forearm's (the figure's own bones, unchanged).

## Defaults taken (owner not asked)

- The left arm is the one raised (the replica hangs from the right hand), as before.
- Straight up but not locked: the elbow keeps 15°, the arm leans 17° out and 14° forward of vertical, so the hand is
  over the shoulder and clear of the head and helmet.
- The hit volume is untouched: a called or walking-off player can't be hit.
- The raised fingertips reach about 2.07 m, just under the HIT! sign (centred 2.25 m); from a low camera they can touch
  its "!". Left as it is: the sign is over the head and the hand beside it.
- A dark edge of the shoulder showing between the helmet and the raised arm (in the old clips too) is a KNOWN_ISSUES
  row, for the figure body work.
