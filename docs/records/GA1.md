# GA1 · The figures' running animations

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | figure, hit and hitbox tests pass (23 files, 243 tests) | pending | – |

## Why

The owner (2026-11-05): "The running animations right now are very bad so they need reworked and improved for the
figure." Filming the figure in game (`tools/gait_pictures.gd`) showed three causes:

- **The legs cycled up to twice too fast and the feet skated.** The game moved every stepping clip one cycle per
  1.33 m (`HitConfig.strides_per_metre` 0.75) whatever the speed, while the clips were made for 2.4 m (run) to 3.2 m
  (sprint) a cycle: a sprint stepped about 9 times a second and every planted foot slid.
- **The clips were thin:** 12 to 17 frames, short stance, both strafes crossing the legs through each other.
- **The upper body rode the hips.** The aim clips lie over the legs from the Spine up, so every turn of the pelvis in
  a stepping clip turned the replica with it.

## What changed

- **New clips** Walk_F, Run_F, Run_B, Run_L, Run_R, Sprint and CrouchWalk, made in code by
  `tools/blender/bot-figure/gait/gait.py` (numpy, no Blender) on the shipped skeleton and spliced into `human.glb` and
  `robot.glb` by `splice.mjs`: clips only, the rig, meshes and every other clip byte for byte as they were. Each foot
  is planted at a fixed spot for its stance and rolls heel, flat, ball (the back-pedal stays on the ball), so it never
  slides at the clip's speed; the swing is a smooth arc (the heel kicked up on a run); the pelvis bobs, sways, turns
  with the swinging leg and drops on its side; the hips sink only where a foot would be out of reach; two-bone IK
  with the knee in the foot's own plane. Keys at 60 a second. The upper body keeps the old clips' (the aim covers it).
- **Cadence by speed** (`HitConfig.cycle_speeds`/`cycle_metres`, crouched `crouch_cycle_*`; `Hitbox.cycle_length`):
  the walk cycle moves one cycle per the clip's own speed × seconds (walk 1.76 m at 2.3 m/s, run 2.94 m at 4.2,
  sprint 3.99 m at 6.3, crouch 1.26 m at 2.1), in line between. `strides_per_metre` is gone.
- **Steady upper body** (`HitConfig.upper_steady`, `FigureBend.steady_upper`, the same turn in `HitPose`): over a
  stepping clip the upper chain is turned back about the hips to standing still's hips heading (`HitFit.still_heading`,
  crouched blended), so the pelvis may swing and turn 38° into a strafe while the replica keeps its heading. The hit
  volume's upper body turns alike (test_hit_fit holds every joint within 4 cm of the drawn one).
- **Clips in step by their travel:** `FigureGraph.forward_time` measures the left leg's swing along the clip's own way
  (back for Run_B, aside for the strafes), so every clip's leading left leg meets FORWARD_PHASE and neighbours blend in
  step.
- **Hit fit** re-baked, at 32 phases (was 24): the faster crouched swing left a 5 cm gap between samples at 24.
- `tools/gait_pictures.gd`: films the figure stepping each gait in game on a chequered floor (before/after pictures).

## Defaults taken (owner not asked)

- Game speeds unchanged (walk 2.3, run 4.2, sprint 6.3, crouch 2.1 m/s); cadence set from them: walk 156, run 171,
  sprint 190, crouch walk 200 steps a minute.
- Strafes turn the pelvis 38° and the feet 52° into the step; the upper body stays square to the aim.
- The crouch walk keeps the hips 0.62 m down (the crouch line) and sits back with the feet ahead, knees up: the
  only way the low hips leave the knees off the floor.
- Sprint leans the pelvis 9° forward, so the shouldered replica dips 9° while sprinting.
